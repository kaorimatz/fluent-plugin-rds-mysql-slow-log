require 'cool.io'
require 'fluent/input'
require 'mysql2'
require 'scanf'
require 'time'

module Fluent
  class RdsMysqlSlowLog < Input
    Plugin.register_input('rds_mysql_slow_log', self)

    config_param :database_timezone, :string, default: nil, desc: 'The timezone of the database.'
    config_param :emit_interval, :time, default: 10, desc: 'The interval in seconds to emit records.'
    config_param :encoding, :string, default: nil, desc: 'The encoding of strings in an emitted record.'
    config_param :from_encoding, :string, default: nil, desc: 'The encoding of sql_text data.'
    config_param :keep_time_key, :bool, default: false, desc: 'Keep the time key in an emitted record.'
    config_param :null_empty_string, :bool, default: false, desc: 'Convert empty strings to null.'
    config_param :tag_prefix, :string, default: nil, desc: 'The prefix of the tag.'
    config_section :server, param_name: :servers, required: true do
      config_param :host, :string, desc: 'The IP address or hostname of the server.'
      config_param :password, :string, default: nil, secret: true, desc: 'The password to use when connecting to the server.'
      config_param :port, :integer, default: 3306, desc: 'The port number of the server.'
      config_param :tag, :string, desc: 'The tag of the event.'
      config_param :username, :string, default: nil, desc: 'The username to use when connecting to the server.'
    end

    def configure(conf)
      super

      configure_servers
      configure_timezone
      configure_encoding
    end

    def configure_servers
      @servers.map! do |s|
        tag = @tag_prefix ? "#{@tag_prefix}.#{s.tag}" : s.tag
        [tag, Server.new(s.host, s.port, s.username, s.password)]
      end
    end

    def configure_timezone
      @database_timezone = parse_timezone_param(@database_timezone) if @database_timezone
    end

    def parse_timezone_param(timezone)
      TZInfo::Timezone.get(timezone)
    rescue InvalidTimezoneIdentifier => e
      raise ConfigError, e.message
    end

    def configure_encoding
      if !@encoding && @from_encoding
        raise ConfigError, "'from_encoding' parameter must be specified with 'encoding' parameter."
      end

      @encoding = parse_encoding_param(@encoding) if @encoding
      @from_encoding = parse_encoding_param(@from_encoding) if @from_encoding
    end

    def parse_encoding_param(encoding)
      Encoding.find(encoding)
    rescue ArgumentError => e
      raise ConfigError, e.message
    end

    def start
      super

      @loop = Coolio::Loop.new
      @timer = TimerWatcher.new(@emit_interval, true, log, &method(:on_timer))
      @loop.attach(@timer)
      @thread = Thread.new(&method(:run))
    end

    def run
      @loop.run
    rescue
      log.error $!.to_s
      log.error_backtrace
    end

    def on_timer
      @servers.each do |tag, server|
        emit_slow_log(tag, server)
      end
    end

    def emit_slow_log(tag, server)
      server.connect do |client|
        client.query('CALL mysql.rds_rotate_slow_log')

        es = MultiEventStream.new
        client.query('SELECT * FROM slow_log_backup').each do |row|
          es.add(*process(row))
        end

        router.emit_stream(tag, es)
      end
    rescue
      log.error $!.to_s
      log.error_backtrace
    end

    def process(record)
      process_timestamp(record)
      process_string(record)
      process_time(record)
      process_integer(record)
      [extract_time(record), record]
    end

    def process_timestamp(record)
      record['start_time'] &&= timestamp_to_time(record['start_time'])
    end

    def timestamp_to_time(timestamp)
      year, month, day, hour, min, sec, usec = timestamp.scanf('%4u-%2u-%2u %2u:%2u:%2u.%6u')
      t = Time.utc(year, month, day, hour, min, sec, usec)
      @database_timezone ? @database_timezone.local_to_utc(t) : t
    end

    def process_string(record)
      if @null_empty_string
        %w[user_host db sql_text].each do |field|
          record[field] = nil if (record[field] || '').empty?
        end
      end

      if @encoding
        encode(record['user_host'], @encoding, Encoding::UTF_8)
        encode(record['db'], @encoding, Encoding::UTF_8)
        encode(record['sql_text'], @encoding, @from_encoding)
      end
    end

    def encode(str, dst, src)
      if str.nil?
        nil
      elsif src
        str.encode!(dst, src)
      else
        str.force_encoding(dst)
      end
    end

    def process_time(record)
      %w[query_time lock_time].each do |field|
        record[field] &&= time_to_microseconds(record[field])
      end
    end

    def time_to_microseconds(time)
      hour, min, sec, usec = time.scanf('%2u:%2u:%2u.%6u')
      hour * 3_600_000_000 + min * 60_000_000 + sec * 1_000_000 + usec.to_i
    end

    def process_integer(record)
      %w[
        rows_sent
        rows_examined
        last_insert_id
        insert_id
        server_id
        thread_id
        rows_affected
      ].each do |field|
        record[field] &&= record[field].to_i
      end
    end

    def extract_time(record)
      time = @keep_time_key ? record['start_time'] : record.delete('start_time')
      (time || Engine.now).to_i
    end

    def shutdown
      super

      @loop.watchers.each(&:detach)
      @loop.stop
      @thread.join
    end

    class Server
      def initialize(host, port, username, password)
        @host = host
        @port = port
        @username = username
        @password = password
      end

      def connect
        client = Mysql2::Client.new(
          host: @host,
          port: @port,
          username: @username,
          password: @password,
          database: 'mysql',
          cache_rows: false,
          cast: false
        )
        yield client
      ensure
        client.close if client
      end
    end

    class TimerWatcher < Coolio::TimerWatcher
      def initialize(interval, repeat, log, &callback)
        @callback = callback
        @log = log
        super(interval, repeat)
      end

      def on_timer
        @callback.call
      rescue
        @log.error $!.to_s
        @log.error_backtrace
      end
    end
  end
end
