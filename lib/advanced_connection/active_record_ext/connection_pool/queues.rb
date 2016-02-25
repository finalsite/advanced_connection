module AdvancedConnection::ActiveRecordExt
  module ConnectionPool
    module Queues
      extend ActiveSupport::Concern

      included do
        class AdvancedQueue < ActiveRecord::ConnectionAdapters::ConnectionPool::Queue; end

        class FifoQueue < AdvancedQueue; end
        class LifoQueue < AdvancedQueue
          def remove
            @queue.pop
          end
        end

        class AgeSortedQueue < AdvancedQueue
          def poll(timeout = nil)
            synchronize do
              @queue.sort_by!(&:instance_age)
              no_wait_poll || (timeout && wait_poll(timeout))
            end
          end
        end

        class YoungAgeBiasedQueue < AgeSortedQueue
          def remove
            @queue.pop
          end
        end

        class OldAgeBiasedQueue < AgeSortedQueue
          def remove
            @queue.shift
          end
        end
      end
    end
  end
end