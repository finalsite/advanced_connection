
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
          attr_reader :thread, :logger
          private :thread

          def initialize(pool, interval)
            @pool     = pool
            @interval = interval.to_i
            @thread   = nil
            @logger   = ActiveSupport::Logger.new(Rails.root.join('log', 'idle_manager.log'))
            @logger.level = Rails.logger.level
          end

          def log_info(format, *args)
            @logger.info(format("#{idle_stats} #{format}", *args))
          end

          def log_debug(format, *args)
            @logger.debug(format("#{idle_stats} #{format}", *args))
          end

          def log_warn(format, *args)
            @logger.debug(format("#{idle_stats} #{format}", *args))
          end

          def dump_stats
            if (stats_dump = Rails.root.join('tmp', 'dump-idle-stats.txt')).exist?
              log_info "Dumping statistics"
              id_size = self.object_id.to_s.size
              @logger.info(format("%3s: %#{id_size}s\t%9s\t%9s", 'IDX', 'OID', 'AGE', 'IDLE'))
              @pool.idle_connections.each_with_index do |connection, index|
                @logger.info(format("%3d: %#{id_size}d\t%9d\t%9d",
                                    index, connection.object_id, connection.instance_age, connection.idle_time))
              end
              !!(stats_dump.unlink rescue true)
            end
          end

          def idle_stats
            stats = @pool.pool_statistics
            format(
              "[#{Time.now}] IdleManager (Actv:%d,Avail:%d,Idle:%d,Total:%d):",
              stats.active, stats.available, stats.idle, stats.total,
            )
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
              log_info("starting idle manager; running every #{interval} seconds")

              loop do
                sleep interval

                begin
                  start = Time.now
                  dump_stats

                  log_debug("beginning idle connection cleanup")
                  pool.remove_idle_connections

                  log_debug("beginning idle connection warmup")
                  pool.create_idle_connections

                  finish = (Time.now - start).round(6)
                  log_info("finished idle connection tasks in #{finish} seconds; next run in #{interval} seconds")
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
          when :fifo, :queue   then Queues::FIFO.new
          else
            Rails.logger.warn "Unknown queue_type #{queue_type.inspect} - using standard FIFO instead"
            Queues::FIFO.new
        end

        @idle_manager = IdleManager.new(self, idle_check_interval).tap(&:start)
      end

      #
      ## SETINGS
      #

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
        idle_manager.log_debug "checking in connection #{conn.object_id} at #{conn.last_checked_in}"
        checkin_without_last_checked_in(conn)
      end

      def idle_connections
        synchronize { @connections.select(&:idle?).sort }
      end

      def pool_statistics
        synchronize do
          total     = @connections.size
          idle      = @connections.count(&:idle?)
          active    = @connections.count(&:in_use?)
          available = total - active

          ActiveSupport::OrderedOptions.new.merge(
            total:     total,
            idle:      idle,
            active:    active,
            available: available
          )
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

      def warmup_connections(count = nil)
        count ||= warmup_connection_count
        slots = connection_limit - @connections.size
        count = slots if slots < count

        return unless slots >= count

        idle_manager.log_info "Warming up #{count} connection#{count > 1 ? 's' : ''}"
        synchronize do
          count.times {
            conn = checkout_new_connection
            @available.add conn
          }
        end
      end

      def remove_idle_connections
        # don't attempt to remove idle connections if we have threads waiting
        if @available.num_waiting > 0
          idle_manager.log_warn "Cannot reap while threads actively waiting on db connections"
          return
        end

        idle_conns = idle_connections
        idle_count = idle_conns.size

        unless idle_count > max_idle_connections
          idle_manager.log_warn "idle count (#{idle_count}) does not exceed max idle connections (#{max_idle_connections}); skipping reap."
          return
        end

        cull_count = (idle_count - max_idle_connections)

        culled = 0
        idle_conns.each_with_index do |conn, idx|
          if idx < cull_count
            if remove_connection(conn)
              culled += 1
              idle_manager.log_info "culled connection ##{idx} id##{conn.object_id} - age:#{conn.instance_age.to_i} idle_time:#{conn.idle_time.to_i}"
            else
              idle_manager.log_info "kept connection ##{idx} id##{conn.object_id} - age:#{conn.instance_age.to_i} idle_time:#{conn.idle_time.to_i}"
            end
          else
            idle_manager.log_info "kept connection ##{idx} id##{conn.object_id} - age:#{conn.instance_age.to_i} idle_time:#{conn.idle_time.to_i}"
          end
        end

        idle_manager.log_info "culled %d connections" % culled
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
    end
  end
end
