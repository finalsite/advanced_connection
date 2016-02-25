module AdvancedConnection::ActiveRecordExt
  module ConnectionPool
    module Queues
      class Default < ActiveRecord::ConnectionAdapters::ConnectionPool::Queue
        def size
          synchronize { @queue.size }
        end
      end

      class Stack < Default
        def remove
          @queue.pop
        end
      end

      class AgeSorted < Default
        def poll(timeout = nil)
          synchronize do
            @queue.sort_by!(&:instance_age)
            no_wait_poll || (timeout && wait_poll(timeout))
          end
        end
      end

      class YoungAgeBiased < AgeSorted
        def remove
          @queue.pop
        end
      end

      class OldAgeBiased < AgeSorted
        def remove
          @queue.shift
        end
      end
    end
  end
end
