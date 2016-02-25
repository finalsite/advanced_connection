module AdvancedConnection
  module ActiveRecordExt
    extend ActiveSupport::Concern
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :AbstractAdapter
      autoload :TransactionEncapsulation
      autoload :WithoutConnection
      autoload :ConnectionPool
    end

    included do
      instance_exec do
        include WithoutConnection
      end

      ActiveRecord::ConnectionAdapters::AbstractAdapter.instance_exec do
        include AbstractAdapter
      end
      ActiveRecord::ConnectionAdapters::ConnectionPool.instance_exec do
        include ConnectionPool::Queues
        include ConnectionPool::IdleManager
      end
    end
  end
end
