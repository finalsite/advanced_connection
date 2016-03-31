#
# Copyright (C) 2016 Finalsite, LLC
# Copyright (C) 2016 Carl P. Corliss <carl.corliss@finalsite.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the "Software"), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#
module AdvancedConnection::ActiveRecordExt
  module ConnectionPool
    module IdleManager
      extend ActiveSupport::Concern

      included do
        alias_method_chain :initialize, :advanced_connection
        alias_method_chain :checkin, :last_checked_in

        attr_reader :idle_manager

        class IdleManager
          attr_accessor :interval
          attr_reader :thread
          private :thread

          def initialize(pool, interval)
            @pool     = pool
            @interval = interval.to_i
            @thread   = nil
          end

          def status
            if @thread
              @thread.alive? ? :running : :dead
            else
              :stopped
            end
          end

          def restart
            stop.start
          end

          def stop
            @thread.kill if @thread.alive?
            @thread = nil
            self
          end

          def start
            return unless @interval > 0

            @thread ||= Thread.new(@pool, @interval) { |pool, interval|
              pool.send(:idle_info, "starting idle manager; running every #{interval} seconds")

              loop do
                sleep interval

                begin
                  start = Time.now
                  pool.send(:idle_info, "beginning idle connection cleanup")
                  pool.remove_idle_connections
                  pool.send(:idle_info, "beginning idle connection warmup")
                  pool.create_idle_connections
                  finish = (Time.now - start).round(6)
                  pool.send(:idle_info, "finished idle connection tasks in #{finish} seconds; next run in #{pool.max_idle_time} seconds")
                rescue => e
                  Rails.logger.error "#{e.class.name}: #{e.message}"
                  e.backtrace.each { |line| Rails.logger.error line }
                end
              end
            }
            self
          end
        end
      end

      def initialize_with_advanced_connection(spec)
        initialize_without_advanced_connection(spec)

        @available = case queue_type
          when :prefer_older   then Queues::OldAgeBiased.new
          when :prefer_younger then Queues::YoungAgeBiased.new
          when :lifo, :stack   then Queues::Stack.new
          else
            Rails.logger.warn "Unknown queue_type #{queue_type.inspect} - using standard FIFO instead"
            Queues::FIFO.new
        end

        @idle_manager = IdleManager.new(self, idle_check_interval).tap(&:start)
      end

      def queue_type
        @queue_type ||= spec.config.fetch(:queue_type,
                                          AdvancedConnection.connection_pool_queue_type).to_s.downcase.to_sym
      end

      def warmup_connection_count
        @warmup_connection_count ||= begin
          conns = spec.config[:warmup_connections] || AdvancedConnection.warmup_connections
          conns.to_i > connection_limit ? connection_limit : conns.to_i
        end
      end

      def max_idle_time
        @max_idle_time ||= (spec.config[:max_idle_time] || \
                           AdvancedConnection.max_idle_time).to_i
      end

      def idle_check_interval
        @idle_check_interval ||= (spec.config[:idle_check_interval] || \
                                 AdvancedConnection.idle_check_interval || \
                                 max_idle_time).to_i
      end

      def max_idle_connections
        @max_idle_connections ||= begin
          begin
            (spec.config[:max_idle_connections] || \
              AdvancedConnection.max_idle_connections).to_i
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
        @connections.select(&:in_use?)
      end

      def available_connections
        @connections.reject(&:in_use?)
      end

      def idle_connections
        available_connections.select do |conn|
          (Time.now - conn.last_checked_in).to_f > max_idle_time
        end.sort { |a, b|
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
        idle = active = available = 0
        synchronize do
          idle      = idle_connections.size
          active    = active_connections.size
          available = available_connections.size
        end
        total = active + available

        ActiveSupport::OrderedOptions.new.merge(
          total:     total,
          idle:      idle,
          active:    active,
          available: available
        )
      end

      def warmup_connections(count = nil)
        count ||= warmup_connection_count
        slots = connection_limit - @connections.size
        count = slots if slots < count

        return unless slots >= count

        idle_info "Warming up #{count} connection#{count > 1 ? 's' : ''}"
        synchronize do
          count.times {
            conn = checkout_new_connection
            @available.add conn
          }
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

        return unless idle_count > max_idle_connections

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
