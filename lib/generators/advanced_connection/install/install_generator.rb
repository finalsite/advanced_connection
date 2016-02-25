module AdvancedConnection
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path('../templates', __FILE__)

    def copy_files
      template "advanced_connection.rb", File.join("config", "initializers", "advanced_connection.rb")
    end
  end
end