begin
  require 'bundler/setup'
  Bundler.setup(:default, :development, :tests)
  Bundler::GemHelper.install_tasks
rescue LoadError
  puts 'You must `gem install bundler` and `bundle install` to run rake tasks'
end

require 'bundler/gem_tasks'
require 'pathname'
require "rspec"
require "rspec/core/rake_task"
require 'rdoc/task'
require 'rake/testtask'

RSpec::Core::RakeTask.new(:spec => %w{ db:copy_credentials db:test:prepare }) do |spec|
  spec.pattern = "spec/**/*_spec.rb"
  # spec.rspec_opts = '--order rand:16996'
end

namespace :spec do
  [:tasks, :unit, :adapters, :integration].each do |type|
    RSpec::Core::RakeTask.new(type => :spec) do |spec|
      spec.pattern = "spec/#{type}/**/*_spec.rb"
    end
  end
end

task :console do
  require 'pry-nav'
  require 'advanced_connection'
  ARGV.clear
  Pry.start
end

RDoc::Task.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = 'rdoc'
  rdoc.title    = 'AdvancedConnection'
  rdoc.options << '--line-numbers'
  rdoc.rdoc_files.include('README.rdoc')
  rdoc.rdoc_files.include('lib/**/*.rb')
end


Rake::TestTask.new(:test) do |t|
  t.libs << 'lib'
  t.libs << 'test'
  t.pattern = 'test/**/*_test.rb'
  t.verbose = false
end

task default: :spec

def config
  @config ||= begin
    require Pathname.new(__FILE__).dirname.join('spec', 'support', 'db_config')
    AdvancedConnection::Test::DbConfig.instance
  end
end

def pg_config
  config.postgresql_config
end

def my_config
  config.mysql_config
end

namespace :db do
  namespace :test do
    task :prepare => %w{postgres:drop_db postgres:build_db mysql:drop_db mysql:build_db}
  end

  config.each do |dbtype, data|
    namespace(dbtype == 'postgresql' ? 'postgres' : dbtype) do
      desc "copy over db config files for #{dbtype} if they don't already exist"
      task :copy_credentials do
        require 'fileutils'
        base_db_file = 'spec/config/database.yml'
        rails_db_file = 'spec/dummy/config/database.yml'

        FileUtils.copy(base_db_file + '.erb', base_db_file, :verbose => true) unless File.exists?(base_db_file)

        data = %w[ development test ].each_with_object({}) { |env, memo|
          memo[env] = config.public_send("#{dbtype}_config")
        }
        $stdout.puts "generating #{rails_db_file}"
        IO.write(rails_db_file, data.to_yaml)
      end
    end
  end
end

namespace :copyright do
  namespace :headers do
    desc 'add copyright headers'
    task :add do
      require 'copyright_header'

      args = {
        license:                        'MIT',
        copyright_software:             'Advanced Connection',
        copyright_software_description: "A Rails plugin providing an Idle Database Connection Manager",
        copyright_holders:              ['Finalsite, LLC', 'Carl P. Corliss <carl.corliss@finalsite.com>'],
        copyright_years:                ['2016'],
        add_path:                       'lib',
        output_dir:                     '.'
      }

      command_line = CopyrightHeader::CommandLine.new( args )
      command_line.execute
    end

    desc 'remove copyright headers'
    task :remove do
      require 'copyright_header'

      args = {
        license:                        'MIT',
        copyright_software:             'Advanced Connection',
        copyright_software_description: "A Rails plugin providing an Idle Database Connection Manager",
        copyright_holders:              ['Finalsite, LLC', 'Carl P. Corliss <carl.corliss@finalsite.com>'],
        copyright_years:                ['2016'],
        remove_path:                    'lib',
        output_dir:                     '.'
      }

      command_line = CopyrightHeader::CommandLine.new( args )
      command_line.execute
    end
  end
end

namespace :postgres do
  require 'active_record'

  desc 'Build the PostgreSQL test databases'
  task :build_db do
    %x{ createdb -E UTF8 #{pg_config['database']} -U#{pg_config['username']} } rescue "test db already exists"
    ActiveRecord::Base.establish_connection pg_config
    ActiveRecord::Migrator.migrate('spec/dummy/db/migrate')
  end

  desc "drop the PostgreSQL test database"
  task :drop_db do
    puts "dropping database #{pg_config['database']}"
    %x{ dropdb #{pg_config['database']} -U#{pg_config['username']} }
  end
end

namespace :mysql do
  require 'active_record'

  desc 'Build the MySQL test databases'
  task :build_db do
    %x{ mysqladmin -u #{my_config['username']} --password=#{my_config['password']} create #{my_config['database']} } rescue "test db already exists"
    ActiveRecord::Base.establish_connection my_config
    ActiveRecord::Migrator.migrate('spec/dummy/db/migrate')
  end

  desc "drop the MySQL test database"
  task :drop_db do
    puts "dropping database #{my_config['database']}"
    %x{ mysqladmin -u #{my_config['username']} --password=#{my_config['password']} drop #{my_config['database']} --force}
  end
end
