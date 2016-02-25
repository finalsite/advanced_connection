#
# Advanced Connection Configuration
#
AdvancedConnection.configure do |config|
  config.transaction_encapsulation    = true
  config.idle_connection_reaping      = true
  config.connection_pool_prestart     = 10
  config.connection_pool_queue_type   = :lifo

  config.without_connection_callbacks     = {
    # runs right before the connection is checked back into the pool
    before_checkin:  ->() { $stderr.puts "Before Checkin"},
    # runs right after the connection is checked back into the pool
    after_checkin:   ->() { $stderr.puts "After Checkin" },
    # runs right before the new connection is checked out from the pool
    before_checkout: ->() { $stderr.puts "Before Checkout" },
    # runs right after the new connection is checked out from the pool
    after_checkout:  ->() { $stderr.puts "After Checkout" }
  }
end
