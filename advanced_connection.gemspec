$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "advanced_connection/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "advanced_connection"
  s.version     = AdvancedConnection::VERSION
  s.authors     = ["Carl P. Corliss"]
  s.email       = ["rabbitt@gmail.com"]
  s.homepage    = "TODO"
  s.summary     = "TODO: Summary of AdvancedConnection."
  s.description = "TODO: Description of AdvancedConnection."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.5.1"

  s.add_development_dependency "sqlite3"
end
