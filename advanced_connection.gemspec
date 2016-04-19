$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "advanced_connection/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "advanced_connection"
  spec.version     = AdvancedConnection::VERSION
  spec.authors     = ["Carl P. Corliss"]
  spec.email       = ["carl.corliss@finalsite.com"]
  spec.homepage    = "https://github.com/finalsite/advanced_connection"
  spec.summary     = "Provides advanced connection options for rails connection pools"
  spec.description = "Adds idle connection management, statement pooling, and other advanced connection features"
  spec.license     = "MIT"

  spec.files = `git ls-files`.split($/)
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  # eventually support this:
  # spec.required_engine_version = {
  #   :ruby     => '~> 2.0',
  #   :jruby    => '~> 1.7',
  # }

  spec.add_runtime_dependency "rails",         "~> 4.1"
  spec.add_runtime_dependency "activerecord",  "~> 4.1"
  spec.add_runtime_dependency "activesupport", "~> 4.1"

  spec.add_development_dependency "rake",      '~> 10.5.0'
  spec.add_development_dependency "rack",      '~> 1.6.4'
  spec.add_development_dependency "rspec",     '~> 3.4.0'
  spec.add_development_dependency "rspec-its", '~> 1.2.0'
  spec.add_development_dependency "rspec-collection_matchers", '~> 1.1.2'

  # optional dependencies
  if RUBY_ENGINE == 'jruby'
    spec.add_development_dependency "activerecord-jdbcpostgresql-adapter", "~> 1.3.19"
  else
    spec.add_development_dependency "pg",      "~> 0.18.4"
    spec.add_development_dependency "pry",     '~> 0.10.3'
    spec.add_development_dependency "pry-nav", '~> 0.2.4'
  end

  spec.add_development_dependency "guard-rspec", '~> 4.6.4'
  spec.add_development_dependency "coveralls",   '~> 0.8.13'
  spec.add_development_dependency 'rabbitt-githooks', '~> 1.6.0'
  spec.add_development_dependency 'copyright-header', '~> 1.0.15'
end
