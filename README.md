# fluent-plugin-rds-mysql-slow-log

[![Gem](https://img.shields.io/gem/v/fluent-plugin-rds-mysql-slow-log.svg?style=flat-square)](https://rubygems.org/gems/fluent-plugin-rds-mysql-slow-log)
[![Gemnasium](https://img.shields.io/gemnasium/kaorimatz/fluent-plugin-rds-mysql-slow-log.svg?style=flat-square)](https://gemnasium.com/kaorimatz/fluent-plugin-rds-mysql-slow-log)

Fluentd input plugin for MySQL slow query log table on Amazon RDS.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fluent-plugin-rds-mysql-slow-log'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fluent-plugin-rds-mysql-slow-log

## Usage

```
<source>
  @type rds_mysql_slow_log
  database_timezone Asia/Tokyo
  emit_interval 30
  encoding utf-8
  from_encoding shift_jis
  keep_time_key
  null_empty_string
  tag_prefix slow_log
  <server>
    host db1.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com
    port 3306
    username user
    password xxxxxxxxxxxx
    tag db1
  </server>
  <server>
    host db2.xxxxxxxxxxxx.us-east-1.rds.amazonaws.com
    port 3306
    username user
    password xxxxxxxxxxxx
    tag db2
  </server>
</source>
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in the gemspec, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/kaorimatz/fluent-plugin-rds-mysql-slow-log.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
