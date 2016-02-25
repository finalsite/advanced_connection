module AdvancedConnection::ActiveRecordExt
  module ConnectionPool
    module StatementPooling
      extend ActiveSupport::Concern

      included do
        alias_method_chain :new_connection, :statement_pooling
      end

      def new_connection_with_statement_pooling
        new_connection_without_statement_pooling.tap { |conn|
          unless conn.respond_to? :around_connection_checkin
            conn.class.instance_exec {
              include AbstractAdapter::StatementPooling
            }
          end
        }
      end
    end
  end
end