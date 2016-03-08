#
# Advanced Connection Configuration
#
AdvancedConnection.configure do |config|
  # config.enable_without_connection      = <%= AdvancedConnection::Config::DEFAULT_CONFIG.enable_without_connection.inspect %>
  # config.enable_statement_pooling       = <%= AdvancedConnection::Config::DEFAULT_CONFIG.enable_statement_pooling.inspect %>
  # config.enable_idle_connection_manager = <%= AdvancedConnection::Config::DEFAULT_CONFIG.enable_idle_connection_manager.inspect %>

  # config.connection_pool_queue_type     = <%= AdvancedConnection::Config::DEFAULT_CONFIG.connection_pool_queue_type.inspect %>
  # config.warmup_connections             = <%= AdvancedConnection::Config::DEFAULT_CONFIG.warmup_connections.inspect %>
  # config.min_idle_connections           = <%= AdvancedConnection::Config::DEFAULT_CONFIG.min_idle_connections.inspect %>
  # config.max_idle_connections           = ::Float::INFINITY
  # config.max_idle_time                  = 1.day

  # config.without_connection_callbacks = {
  #   # runs right before the connection is checked back into the pool
  #   before:  ->() { },
  #   around:  ->(&block) {
  #     tenant = Apartment::Tenant.current
  #     block.call
  #     Apartment::Tenant.switch(tenant)
  #   },
  #   # runs right after the connection is checked back out of the pool
  #   after:  ->() { }
  # }
  #
  # If you are using this with Apartment, you'll want to setup your Apartment
  # elevator like so:
  #
  # lib/apartment/elevators/my_elevator.rb:
  # module Apartment::Elevators
  #   class MyElevator < Generic
  #     def call(env)
  #       Thread.current['tenant'] = @processor.call(Rack::Request.new(env))
  #       super
  #     ensure
  #       Thread.current['tenant'] = nil
  #       Apartment::Tenant.reset
  #     end
  #   end
  #   . . .
  # end
  #
  # and then set your statement_pooling_callbacks like so:
  #
  # config.statement_pooling_callbacks = {
  #   # switch back to the stored tenant prior to executing sql
  #   before:  ->() {
  #     if Thread.current[:tenant]
  #       Apartment::Tenant.switch(Thread.current[:tenant])
  #     end
  #   }
  # }
end
