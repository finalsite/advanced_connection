module AdvancedConnection
  module ActiveRecordExt
    module ConnectionPool
      extend ActiveSupport::Concern
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :Queues
        autoload :IdleManager
      end

      included do
        ActiveRecord::ConnectionAdapters::ConnectionPool.instance_exec do
          extend Queues
          include IdleManager
        end
      end
    end
  end
end