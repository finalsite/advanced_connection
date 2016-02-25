require 'active_record/connection_adapters/abstract_adapter'

module AdvancedConnection
  module ActiveRecordExt
    extend ActiveSupport::Concern
    extend ActiveSupport::Autoload

    eager_autoload do
      autoload :AbstractAdapter
      autoload :ConnectionPool
    end

    included do
      ActiveRecord::ConnectionAdapters::AbstractAdapter.instance_exec do
        include AbstractAdapter
      end

      ActiveRecord::ConnectionAdapters::ConnectionPool.instance_exec do
        if AdvancedConnection.enable_idle_connection_manager
          include ConnectionPool::IdleManager
        end

        if AdvancedConnection.enable_statement_pooling
          include ConnectionPool::StatementPooling
        elsif AdvancedConnection.enable_without_connection
          include ConnectionPool::WithoutConnection
        end
      end
    end
  end
end
