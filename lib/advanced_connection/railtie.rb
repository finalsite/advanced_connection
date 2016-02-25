module AdvancedConnection
  class Railtie < Rails::Railtie
    config.advanced_connection = ActiveSupport::OrderedOptions.new

    ActiveSupport.on_load(:before_initialize) do
      ActiveSupport.on_load(:active_record) do
        ActiveRecord::Base.send(:include, AdvancedConnection)
      end
    end

    initializer "advanced_connection.configure", after: :load_config_initializers do |app|
      # attempt to load configuration unless it was already loaded
      #  via an existing initializer
      AdvancedConnection.configure(false) do |config|
        {
          transaction_encapsulation:    false,
          idle_connection_reaping:      false,
          connection_pool_prestart:     false,
          connection_pool_queue_type:   :fifo,
          without_connection_callbacks: {}.with_indifferent_access
        }.each do |option, default|
          if app.config.respond_to? option.to_sym
            value = app.config.advanced_connection.send(option) || default
            $stderr.puts "Setting #{option} to #{value}"
            config.send("#{option}=", app.config.advanced_connection.send(option) || default)
          else
            $stderr.puts "Setting #{option} to #{default}"
            config.send("#{option}=", default)
          end
        end
      end
    end

    config.after_initialize do
      unless AdvancedConnection.without_connection_callbacks.empty?
        AdvancedConnection.without_connection_callbacks.each do |callback, proc|
          if callback =~ /^(before|after)_(checkin|checkout)$/
            unless proc.respond_to? :call
              raise Error::ConfigError, "Expected without_connection callback #{callback} to be a callable."
            end
            Rails.logger.debug "Assigning without_connection callback #{$1} #{$2}"
            ActiveRecord::Base.send(:set_callback, "without_connection_#{$2}".to_sym, $1.to_sym, proc)
          end
        end
      end

      if AdvancedConnection.connection_pool_prestart
        handler = ActiveRecord::Base.connection_handler
        handler.connection_pool_list.each do |pool|
          pool.prestart(pool.prestart_connection_count)
        end
      end

      if $COMMAND_NAME == 'irb'
        $stderr.puts "fixing logger"
        Rails.logger = ActiveSupport::Logger.new(Rails.root.join('log', "#{Rails.env}.log"))
      end
    end
  end
end