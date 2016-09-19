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
          attr_reader :logger

          def initialize(pool, interval)
            @pool     = pool
            @interval = interval.to_i
            @logger   = ActiveSupport::Logger.new(Rails.root.join('log', 'idle_manager.log'))

            @logger.level = AdvancedConnection.idle_manager_log_level || ::Logger::INFO
          end

          %w[debug info warn error].each do |level|
            define_method("log_#{level}") do |fmt, *args|
              @logger.send(level, format("[#{Time.now}] #{idle_stats} #{level.upcase}: #{fmt}", *args))
            end
          end

          def reserved_connections
            reserved = @pool.instance_variable_get(:@reserved_connections).dup
            Hash[reserved.keys.zip(reserved.values)]
          end

          def dump_connections
            return unless (stats_dump = Rails.root.join('tmp', 'dump-connections.txt')).exist?

            log_info "Dumping connections"

            id_size = object_id.to_s.size
            @logger.info(format("%3s: %#{id_size}s\t%9s\t%9s\t%4s\t%s", 'IDX', 'OID', 'AGE', 'IDLE', 'ACTV', 'OWNER'))

            @pool.connections.dup.each_with_index do |connection, index|
              if connection.in_use?
                thread_id    = reserved_connections.index(connection) || 0
                thread_hexid = "0x" << (thread_id << 1).to_s(16)
              end

              @logger.info(format("%3d: %#{id_size}d\t%9d\t%9d\t%4s\t%s",
                                  index, connection.object_id,
                                  connection.instance_age, connection.idle_time,
                                  connection.in_use?.to_s, thread_hexid))
            end

            !!(stats_dump.unlink rescue true) # rubocop:disable Style/RescueModifier
          end

          def idle_stats
            stats = @pool.pool_statistics
            format("[Act: %d / Avail: %d (%d idle) / Total: %d]",
                   stats.active, stats.available, stats.idle, stats.total)
          end

          def safe_timed_run(last_run = nil)
            return unless block_given?

            log_debug "last run was #{Time.now - last_run} seconds ago" if last_run

            begin
              start = Time.now
              yield
            rescue StandardError => e
              log_error "#{e.class.name}: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
            ensure
              finish = ((last_run = Time.now) - start).round(6)
              log_info("finished idle connection tasks in #{finish} seconds")
            end

            last_run
          end

          def run
            return unless @interval > 0

            Thread.new(@pool, @interval) do |pool, interval|
              Thread.current.name = self.class.name if Thread.current.respond_to? :name=

              begin
                pool.release_connection if pool.active_connection?
              rescue StandardError => e
                log_error "#{e.class.name}: #{e.message}\n\t#{e.backtrace.join("\n\t")}"
              end

              log_info("starting idle manager; running every #{interval} seconds")
              last_run = nil

              loop {
                sleep interval

                last_run = safe_timed_run(last_run) do
                  dump_connections
                  pool.remove_idle_connections
                end
              }
            end

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

        @idle_manager = IdleManager.new(self, idle_check_interval).tap(&:run)
      end

      def queue_type
        @queue_type ||= spec.config.fetch(
          :queue_type, AdvancedConnection.connection_pool_queue_type
        ).to_s.downcase.to_sym
      end

      def max_idle_connections
        @max_idle_connections ||= begin
          begin
            spec.config.fetch(:max_idle_connections, AdvancedConnection.max_idle_connections).to_i
          rescue FloatDomainError => e
            raise unless e.message =~ /infinity/i
            ::Float::INFINITY
          end
        end
      end

      def max_idle_time
        @max_idle_time ||= begin
          spec.config.fetch(:max_idle_time, AdvancedConnection.max_idle_time).to_i
        end
      end

      def idle_check_interval
        @idle_check_interval ||= begin
          spec.config[:idle_check_interval]  || \
          AdvancedConnection.idle_check_interval || \
          max_idle_time
        end.to_i
      end

      def checkin_with_last_checked_in(conn)
        begin
          if conn.last_checked_out
            previous_checkin, conn.last_checked_in = conn.last_checked_in, Time.now
            idle_manager.log_debug "checking in connection %s at %s (checked out for %.3f seconds)",
                                   conn.object_id, conn.last_checked_in,
                                   (conn.last_checked_in - conn.last_checked_out).to_f.round(6)
          else
            idle_manager.log_debug "checking in connection #{conn.object_id}"
          end
        ensure
          checkin_without_last_checked_in(conn)
        end
      end

      def pool_statistics
        ActiveSupport::OrderedOptions.new.merge(
          total:     (total  = @connections.size),
          idle:      (idle   = @connections.count(&:idle?)),
          active:    (active = @connections.count(&:in_use?)),
          available: (total - active)
        )
      end

      def idle_connections
        @connections.select(&:idle?).sort
      end

      def remove_idle_connections
        # don't attempt to remove idle connections if we have threads waiting
        if @available.num_waiting > 0
          idle_manager.log_warn "Skipping reap while #{@available.num_waiting} thread(s) are actively waiting on database connections..."
          return
        end

        return unless (candidates = idle_connections.size - max_idle_connections) > 0
        idle_manager.log_info "attempting to reap #{candidates} candidate connections"

        reaped = 0

        synchronize do
          idle_connections[0...candidates].each_with_index { |conn, idx|
            if remove_connection(conn)
              reaped += 1
              idle_manager.log_info "reaped candidate connection #%d id#%d age:%d idle:%d" % [
                idx, conn.object_id, conn.instance_age.to_i, conn.idle_time.to_i
              ]
            else
              idle_manager.log_info "kept candidate connection #%d id#%d age:%d idle:%d" % [
                idx, conn.object_id, conn.instance_age.to_i, conn.idle_time.to_i
              ]
            end
          }
        end

        idle_manager.log_info "reaped #{reaped} of #{candidates} candidate connections"
      end

    private

      def remove_connection(conn)
        return false if conn.in_use?

        remove(conn.tap { |c| c.disconnect! })
        true
      end
    end
  end
end
