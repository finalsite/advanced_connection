#
# Advanced Connection Configuration
#
AdvancedConnection.configure do |config|
  #
  ## Idle Manager
  #
  # Enabling this will enable idle connection management. This allows you to specify settings
  # to enable automatic warmup of connections on rails startup, min/max idle connections and
  # idle connection culling.
  #
  config.enable_idle_connection_manager = true

  # Pool queue type determines both how free connections will be checkout out
  # of the pool, as well as how idle connections will be culled. The options are:
  #
  #  :fifo           - All connections will have an equal opportunity to be used and culled (default)
  #  :lifo/:stack    - More frequently used connections will be reused, leaving less frequently used
  #                    connections to be culled
  #  :prefer_older   - Longer lived connections will tend to stick around longer, with younger
  #                    connections being culled
  #  :prefer_younger - Younger lived connections will tend to stick around longer, with older
  #                    connections being culled
  #
  config.connection_pool_queue_type = :prefer_older

  # How many connections to prestart on initial startup of rails. This can
  # help to reduce the time it takes a restarted production node to start
  # responding again.
  #
  config.warmup_connections = 10

  # Minimum number of connection to keep idle. If, during the idle check, you have fewer
  # than this many connections idle, then a number of new connections will be created
  # up to this this number.
  #
  config.min_idle_connections = 5

  # Maximum number of connections that can remain idle without being culled. If you have
  # more idle conections than this, only the difference between the total idle and this
  # maximum will be culled.
  #
  config.max_idle_connections = 5

  # How long (in seconds) a connection can remain idle before being culled
  #
  config.max_idle_time = 90

  # How many seconds between idle checks (defaults to max_idle_time)
  #
  config.idle_check_interval = 30

  #
  ## Without Connection
  #
  # Enabling this will add a new method to ActiveRecord::Base that allows you to
  # mark a block of code as not requiring a connection. This can be useful in reducing
  # pressure on the pool, especially when you have sections of code that make
  # potentially long-lived external requests. E.g.,
  #
  # require 'open-uri'
  # results = ActiveRecord::Base.without_connection do
  #   open('http://some-slow-site.com/api/foo')
  # end
  #
  # During the call to the remote site, the db connection is checked in and subsequently
  # checked back out once the block finishes.
  #
  # To enable this feature, uncomment the following:
  #
  config.enable_without_connection = true
  #
  # WARNING: this feature cannot be enabled with Statement Pooling.
  #
  # Additionally, you can hook into the checkin / chekcout lifecycle by way of callbacks. This
  # can be extremely useful when employing something like Apartment to manage switching
  # between tenants.
  #
  config.without_connection_callbacks = {
    # runs right before the connection is checked back into the pool
    around:  ->(&block) {
      $stderr.puts "storing tenant"
      #tenant = Apartment::Tenant.current
      block.call
      $stderr.puts "restoring tenant"
      #Apartment::Tenant.switch!(tenant)
    },
  }
  #
  ## Statement Pooling
  #
  # **** WARNING **** EXPERIMENTAL **** WARNING **** EXPERIMENTAL ****
  #
  # THIS FEATURE IS HIGHLY EXPERIMENTAL AND PRONE TO FAILURE. DO NOT USE UNLESS
  # YOU PLAN TO AIDE IN IT'S DEVELOPMENT.
  #
  # When enabled, this feature causes your connections to immediately be returned to
  # the pool upon completion of each query (with the exception of transactions, where
  # the connection is returned after transaction commit/rollback). This can help to
  # reduce pressure on the pool, as well as the number of the connections to the
  # backend by making more efficient use of existing connections.
  #
  # WARNING: this cannot be enabled with Without Connection.
  #
  # To enable, simply uncomment the following:
  #
  # config.enable_statement_pooling = true
  #
  # Additionally, callbacks are provided around the connection checkin. This can
  # be extremely useful when in a multi-tenant situation using something like
  # Apartment, e.g.:
  #
  # lib/apartment/elevators/my_elevator.rb:
  # module Apartment::Elevators
  #   class MyElevator < Generic
  #     def call(env)
  #       super
  #     ensure
  #       Thread.current[:tenant] = nil
  #       Apartment::Tenant.reset
  #     end
  #
  #     def parse_tenant_name(request)
  #       request.host.split('.').first.tap do |tenant|
  #         Thread.current[:tenant] = tenant
  #       end
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
