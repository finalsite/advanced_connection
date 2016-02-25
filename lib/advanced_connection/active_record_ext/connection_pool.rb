require 'active_record/connection_adapters/abstract/connection_pool'

module AdvancedConnection
  module ActiveRecordExt
    module ConnectionPool
      extend ActiveSupport::Autoload

      eager_autoload do
        autoload :Queues
        autoload :IdleManager
        autoload :StatementPooling
        autoload :TransactionEncapsulation
        autoload :WithoutConnection
      end
    end
  end
end