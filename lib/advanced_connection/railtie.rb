module AdvancedConnection
  class Railtie < Rails::Railtie
    config.advanced_connection = ActiveSupport::OrderedOptions.new

    ActiveSupport.on_load(:before_initialize) do
      ActiveSupport.on_load(:active_record) do
        load Rails.root.join('config', 'initializers', 'advanced_connection.rb')
        ActiveRecord::Base.send(:include, AdvancedConnection::ActiveRecordExt)
      end
    end

    config.after_initialize do
      if AdvancedConnection.enable_idle_connection_manager && AdvancedConnection.warmup_connections
        ActiveRecord::Base.connection_handler.connection_pool_list.each(&:warmup_connections)
      end
    end
  end
end