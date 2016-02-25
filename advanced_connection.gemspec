$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "advanced_connection/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = "advanced_connection"
  spec.version     = AdvancedConnection::VERSION
  spec.authors     = ["Carl P. Corliss"]
  spec.email       = ["rabbitt@gmail.com"]
  spec.homepage    = "https://github.com/finalsite/advanced_connection"
  spec.summary     = "TODO: Summary of AdvancedConnection."
  spec.description = "TODO: Description of AdvancedConnection."
  spec.license     = "LGPL"

  spec.files = `git ls-files`.split($/)
  spec.test_files = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  # eventually support this:
  # spec.required_engine_version = {
  #   :ruby     => '~> 2.0',
  #   :jruby    => '~> 1.7.24',
  # }

  spec.add_runtime_dependency "rails",         ">= 4.1.0", "< 5.0"
  spec.add_runtime_dependency "activerecord",  ">= 4.1.0", "< 5.0"
  spec.add_runtime_dependency "activesupport", ">= 4.1.0", "< 5.0"

  spec.add_development_dependency "rake"
  spec.add_development_dependency "rack"
  spec.add_development_dependency "rspec", "~> 3.4.0"
  spec.add_development_dependency "rspec-its"
  spec.add_development_dependency "rspec-collection_matchers"

  # optional dependencies
  if RUBY_ENGINE == 'jruby'
    spec.add_development_dependency "activerecord-jdbcpostgresql-adapter", "~> 1.3.10"
  else
    spec.add_development_dependency "pg", "~> 0.18.4"
    spec.add_development_dependency "pry"
    spec.add_development_dependency "pry-nav"
  end


  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "coveralls"
end
