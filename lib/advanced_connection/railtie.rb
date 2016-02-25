module AdvancedConnection
  class Railtie < Rails::Railtie
    config.advanced_connection = ActiveSupport::OrderedOptions.new

    initializer "advanced_connection.configure", after: :load_config_initializers do |app|
      # attempt to load configuration unless it was already loaded
      #  via an existing initializer
      AdvancedConnection.configure(false) do |config|
        {
          enable_statement_pooling:       false,
          enable_without_connection:      false,
          enable_idle_connection_manager: false,
        }.each do |option, default|
          if app.config.respond_to? option.to_sym
            value = app.config.advanced_connection.send(option) || default
            config.send("#{option}=", app.config.advanced_connection.send(option) || default)
          else
            config.send("#{option}=", default)
          end
        end
      end
    end

    config.after_initialize do
      ActiveRecord::Base.send(:include, AdvancedConnection)

      if AdvancedConnection.enable_idle_connection_manager && AdvancedConnection.prestart_connections
        ActiveRecord::Base.connection_handler.connection_pool_list.each(&:prestart)
      end
    end
  end
end