#
# Advanced Connection Configuration
#
AdvancedConnection.configure do |config|
  # config.transaction_encapsulation = false

  # config.idle_connection_reaping = true

  # config.pool_warmup = false
  # config.pool_queue_type = :fifo

  # config.without_connection_callbacks     = {
  #   # runs right before the connection is checked back into the pool
  #   before_checkin:  ->() {
  #     if defined? Apartment
  #       Thread.current[:tenant] = Apartment::Tenant.current
  #     end
  #   },
  #   # runs right after the connection is checked back into the pool
  #   after_checkin:   ->() { },
  #   # runs right before the new connection is checked out from the pool
  #   before_checkout: ->() { },
  #   # runs right after the new connection is checked out from the pool
  #   after_checkout:  ->() {
  #     if defined?(Apartment) && Thread.current.include? :tenant
  #       Apartment::Tenant.switch(Thread.current[:tenant])
  #     end
  #   }
  # }
end
