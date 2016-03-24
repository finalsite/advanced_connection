module AdvancedConnection::ActiveRecordExt
  module ConnectionPool
    module IdleManager
      extend ActiveSupport::Concern

      included do
        alias_method_chain :initialize, :advanced_connection
        alias_method_chain :checkin, :last_checked_in

        class IdleManager
          attr_reader :pool, :interval, :thread

          def initialize(pool, interval)
            @pool     = pool
            @interval = interval.to_i
            @thread   = nil
          end

          def run
            return unless interval > 0

            @thread ||= Thread.new(pool, interval) { |_pool, _interval|
              _pool.send(:idle_info, "starting idle manager; running every #{_interval} seconds")

              loop do
                sleep _interval

                begin
                  start = Time.now.to_f
                  _pool.send(:idle_info, "beginning idle connection cleanup")
                  _pool.remove_idle_connections
                  _pool.send(:idle_info, "beginning idle connection warmup")
                  _pool.create_idle_connections
                  finish = (Time.now.to_f - start).round(3)
                  _pool.send(:idle_info, "finished idle connection tasks in #{finish} seconds.; next run in #{pool.max_idle_time} seconds")
                rescue => e
                  Rails.logger.error e
                end
              end
            }
          end
        end
      end

      def initialize_with_advanced_connection(spec)
        initialize_without_advanced_connection(spec)

        @available  = case queue_type
          when :prefer_older   then Queues::OldAgeBiased.new
          when :prefer_younger then Queues::YoungAgeBiased.new
          when :lifo, :stack   then Queues::Stack.new
        else
          Rails.logger.warn "Unknown queue_type #{queue_type.inspect} - using FIFO instead"
          Queues::Default.new
        end

        @idle_manager = IdleManager.new(self, idle_check_interval).tap { |m| m.run }
      end

      def queue_type
        @queue_type ||= begin
          type = spec.config.fetch(:queue_type,
            AdvancedConnection.connection_pool_queue_type).to_s.downcase.to_sym
        end
      end

      def warmup_connection_count
        @warmup_connection_count ||= begin
          conns = spec.config[:warmup_connections] || AdvancedConnection.warmup_connections
          conns.to_i > connection_limit ? connection_limit : conns.to_i
        end
      end

      def max_idle_time
        @max_idle_time ||= begin
          (spec.config[:max_idle_time] || AdvancedConnection.max_idle_time).to_i
        end
      end

      def idle_check_interval
        @idle_check_interval ||= begin
          (spec.config[:idle_check_interval] || AdvancedConnection.idle_check_interval || max_idle_time).to_i
        end
      end

      def max_idle_connections
        @max_idle_connections ||= begin
          begin
            (spec.config[:max_idle_connections] || AdvancedConnection.max_idle_connections).to_i
          rescue FloatDomainError => e
            raise unless e.message =~ /infinity/i
            ::Float::INFINITY
          end
        end
      end

      def min_idle_connections
        @min_idle_connections ||= begin
          min_idle = (spec.config[:min_idle_connections] || AdvancedConnection.min_idle_connections).to_i
          min_idle = (min_idle > 0 ? min_idle : 0)
          min_idle <= max_idle_connections ? min_idle : max_idle_connections
        end
      end

      def connection_limit
        @size
      end

      def checkin_with_last_checked_in(conn)
        conn.last_checked_in = Time.now
        idle_debug "checking in connection #{conn.object_id} at #{conn.last_checked_in}"
        checkin_without_last_checked_in(conn)
      end

      def active_connections
        @connections.select { |conn| conn.in_use? }
      end

      def available_connections
        @connections.reject(&:in_use?)
      end

      def idle_connections
        available_connections.select do |conn|
          (Time.now - conn.last_checked_in).to_f > max_idle_time
        end.sort { |a,b|
          case queue_type
            when :prefer_younger then
              # when prefering younger, we sort oldest->youngest
              # this ensures that older connections will be culled
              # during #remove_idle_connections()
              -(a.instance_age <=> b.instance_age)
            when :prefer_older then
              # when prefering older, we sort youngest->oldest
              # this ensures that younger connections will be culled
              # during #remove_idle_connections()
              (a.instance_age <=> b.instance_age)
            else
              # with fifo / lifo queues, we only care about the
              # last time a given connection was used (inferred
              # by when it was last checked into the pool).
              # This ensures that the longer idling connections
              # will be culled.
              -(a.last_checked_in <=> b.last_checked_in)
          end
        }
      end

      def pool_statistics
        synchronize do
          ActiveSupport::OrderedOptions.new.merge({
            total: @connections.size,
            idle: idle_connections.size,
            active: active_connections.size,
            available: available_connections.size,
          })
        end
      end

      def warmup_connections(count = nil)
        count ||= warmup_connection_count
        slots = connection_limit - @connections.size
        count = slots if slots < count

        if slots >= count
          idle_info "Warming up #{count} connection#{count > 1 ? 's' : ''}"
          synchronize do
            count.times {
              conn = checkout_new_connection
              @available.add conn
            }
          end
        end
      end

      def create_idle_connections
        idle_count = idle_connections.size
        open_slots = connection_limit - @connections.size

        # if we already have enough idle connections, do nothing
        return unless idle_count < min_idle_connections

        # if we don't have enough available slots (i.e., current pool size
        # is greater than max pool size) then do nothing
        return unless open_slots > 0

        # otherwise, spin up connections up to our min_idle_connections setting
        create_count = min_idle_connections - idle_count
        create_count = open_slots if create_count > open_slots

        warmup_connections(create_count)
      end

      def remove_idle_connections
        # don't attempt to remove idle connections if we have threads waiting
        return if @available.num_waiting > 0

        idle_conns = idle_connections
        idle_count = idle_conns.size

        if idle_count > max_idle_connections
          cull_count = (idle_count - max_idle_connections)

          culled = 0
          idle_conns.each_with_index do |conn, idx|
            last_ci = (Time.now - conn.last_checked_in).to_f
            if idx < cull_count
              culled += remove_connection(conn) ? 1 : 0
              idle_info "culled connection ##{idx} id##{conn.object_id} - age:#{conn.instance_age} last_checkin:#{last_ci}"
            else
              idle_info "kept connection ##{idx} id##{conn.object_id} - age:#{conn.instance_age} last_checkin:#{last_ci}"
            end
          end

          idle_info "culled %d connections" % culled
        end
      end

    private

      def remove_connection(conn)
        synchronize do
          return false if conn.in_use?
          remove conn
          conn.disconnect!
        end
        true
      end

      def idle_message(format, *args)
        stats = pool_statistics
        format(
          "IdleManager (Actv:%d,Avail:%d,Idle:%d,Total:%d): #{format}",
          stats.active, stats.available, stats.idle, stats.total,
          *args
        )
      end

      def idle_debug(format, *args)
        Rails.logger.debug idle_message(format, *args)
      end

      def idle_info(format, *args)
        Rails.logger.info idle_message(format, *args)
      end
    end
  end
end