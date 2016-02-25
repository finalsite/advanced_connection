#
# Advanced Connection Configuration
#
AdvancedConnection.configure do |config|
  config.enable_without_connection      = false
  config.enable_statement_pooling       = true
  config.enable_idle_connection_manager = true
  config.connection_pool_queue_type     = :lifo

  config.prestart_connections           = 10
  config.min_idle_connections           = 5
  config.max_idle_connections           = ::Float::INFINITY
  config.max_idle_time                  = 300

  config.without_connection_callbacks = {
    # runs right before the connection is checked back into the pool
    before:  ->() { $stderr.puts "      -> Before callback called" },
    around:  ->(&block) {
      # tenant = Apartment::Tenant.current
      block.call
      # Apartment::Tenant.switch(tenant)
    },
    # runs right after the connection is checked back out of the pool
    after:  ->() { $stderr.puts "      -> After callback called" }
  }

  config.statement_pooling_callbacks  = {
    # # runs right before the connection is checked back into the pool
    # before:  ->() {
    #   $stderr.puts "      -> Before callback called"
    # },
    around:  ->(&block) {
      Thread.current[:tenant] = :foo
      $stderr.puts "    -> setting tenant (#{Thread.current[:tenant]})"
      block.call
      # Apartment::Tenant.switch(tenant)
    },
    # # runs right after the connection is checked back out of the pool
    # after:  ->() {
    #   $stderr.puts "      -> After callback called"
    # }
  }
end
