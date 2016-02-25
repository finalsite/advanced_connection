require 'active_record/connection_adapters/abstract/connection_pool'
require 'hirb'

module AdvancedConnection::ActiveRecordExt
  module ConnectionPool
    module IdleManager
      extend ActiveSupport::Concern

      included do
        alias_method_chain :initialize, :advanced_connection
        alias_method_chain :checkin, :last_checked_in

        class IdleManager
          attr_reader :pool
          private :pool

          def initialize(pool)
            @pool    = pool
            @thread  = nil
          end

          def run
            return @thread if @thread
            return nil unless pool.max_idle_time > 0

            @thread = Thread.new {
              loop do
                sleep pool.max_idle_time
                pool.remove_idle_connections
                pool.create_idle_connections
              end
            }
          end
        end
      end

      def initialize_with_advanced_connection(spec)
        initialize_without_advanced_connection(spec)

        @available  = case pool_queue_type
          when :prefer_older then
            ConnectionPool::OldAgeBiasedQueue.new
          when :prefer_younger then
            ActiveRecord::ConnectionAdapters::ConnectionPool::YoungAgeBiasedQueue.new
          when :lifo then
            ActiveRecord::ConnectionAdapters::ConnectionPool::LifoQueue.new
          else
            ActiveRecord::ConnectionAdapters::ConnectionPool::FifoQueue.new
        end

        if AdvancedConnection.idle_connection_reaping
          @idle_manager = IdleManager.new(self).tap { |m| m.run }
        end
      end

      def pool_queue_type
        @pool_queue_type ||= begin
          type = spec.config.fetch(:pool_queue_type,
            AdvancedConnection.connection_pool_queue_type)
          type.to_s.downcase.to_sym
        end
      end

      def prestart_connection_count
        @prestart_connection_count ||= begin
          conns = spec.config[:prestart_connections] || AdvancedConnection.connection_pool_prestart
          conns.to_i > connection_limit ? connection_limit : conns.to_i
        end || AdvancedConnection.connection_pool_prestart
      end

      def max_idle_time
        @max_idle_time ||= spec.config[:max_idle_time].to_i
      end

      def max_idle_connections
        @max_idle_connections ||= begin
          (idle = spec.config[:max_idle_connections].to_i) > 0 ? idle : 1
        end
      end

      def min_idle_connections
        @min_idle_connections ||= begin
          min = ((idle = spec.config[:min_idle_connections].to_i) > 0 ? idle : 0)
          min <= max_idle_connections ? min : max_idle_connections
        end
      end

      def connection_limit
        @size
      end

      def checkin_with_last_checked_in(conn)
        conn.last_checked_in = Time.now
        checkin_without_last_checked_in(conn)
      end

      def active_connections
        @connections.select { |conn| conn.in_use? }
      end

      def idle_connections
        synchronize do
          @connections.select do |conn|
            !conn.in_use? && (Time.now - conn.last_checked_in).to_i > max_idle_time
          end.sort { |a,b|
            case pool_queue_type
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
      end

      def prestart(count)
        synchronize do
          slots = connection_limit - @connections.size
          count = slots if slots < count

          if slots >= count
            idle_debug "Warming up #{count} connection#{count > 1 ? 's' : ''}"
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

        return unless idle_count < min_idle_connections
        return unless open_slots > 0

        create_count = min_idle_connections - idle_count
        create_count = open_slots if create_count > open_slots
        prestart(create_count)
      end

      def remove_idle_connections
        return if @available.num_waiting > 0

        idle_conns = idle_connections
        idle_count = idle_conns.size

        if idle_count > max_idle_connections
          cull_count = (idle_count - max_idle_connections)
          culled = idle_conns[0...cull_count].inject(0) do |acc, conn|
            acc += remove_connection(conn) ? 1 : 0
          end
          table idle_connections, fields: [ :instance_age, :last_checked_in ]

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

      def idle_debug(message)
        Rails.logger.debug "[#{Thread.current.object_id} " \
                           "(active:#{active_connections.size})]: #{message}"
      end

      def idle_info(message)
        Rails.logger.info "[#{Thread.current.object_id} " \
                          "(active:#{active_connections.size})]: #{message}"
      end
    end
  end
end