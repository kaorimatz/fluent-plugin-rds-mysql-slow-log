# coding: utf-8

lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = 'fluent-plugin-rds-mysql-slow-log'
  spec.version       = '0.2.0'
  spec.authors       = ['Satoshi Matsumoto']
  spec.email         = ['kaorimatz@gmail.com']

  spec.summary       = 'Fluentd input plugin for MySQL slow query log table on Amazon RDS'
  spec.description   = 'Fluentd input plugin for MySQL slow query log table on Amazon RDS.'
  spec.homepage      = 'https://github.com/kaorimatz/fluent-plugin-rds-mysql-slow-log'
  spec.license       = 'MIT'

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = 'exe'
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']

  spec.add_dependency 'fluentd', '>= 0.10.58'
  spec.add_dependency 'mysql2'
  spec.add_dependency 'tzinfo'

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rubocop'
end
