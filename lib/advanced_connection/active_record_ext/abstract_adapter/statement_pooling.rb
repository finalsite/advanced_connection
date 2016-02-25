require 'active_record/connection_adapters/abstract_adapter'

module AdvancedConnection::ActiveRecordExt
  module AbstractAdapter
    module StatementPooling
      extend ActiveSupport::Concern

      module ExecuteWrapper
        def __wrap_adapter_exec_method(*methods)
          Array(methods).flatten.collect(&:to_sym).each { |exec_method|
            class_eval(<<-EOS, __FILE__, __LINE__ + 1)
              def #{exec_method}_with_callback(sql, *args, &block)
                if sql =~ /^BEGIN/i || transaction_open? || pool.nil?
                  #{exec_method}_without_callback(sql, *args, &block)
                else
                  run_callbacks(:statement_pooling_connection_checkin) do
                    #{exec_method}_without_callback(sql, *args, &block).tap {
                      pool.release_connection
                    }
                  end
                end
              end
            EOS
            alias_method_chain exec_method, :callback
          }
        end
        alias_method :__wrap_adapter_exec_methods, :__wrap_adapter_exec_method
      end

      included do
        extend ExecuteWrapper

        define_callbacks :statement_pooling_connection_checkin
        set_callback :statement_pooling_connection_checkin, :around, :around_connection_checkin
        set_callback :statement_pooling_connection_checkin, :before, :before_connection_checkin
        set_callback :statement_pooling_connection_checkin, :after, :after_connection_checkin

        DEFAULT_EXEC_METHODS = [ :execute, :exec_no_cache, :query ]
        JDBC_EXEC_METHODS = %w[
          execute
          exec_query
          exec_query_raw
          exec_insert
          exec_update
          exec_delete
          transaction
        ].collect(&:to_sym)

        if RUBY_ENGINE == 'jruby'
          JDBC_EXEC_METHODS.each { |m| __wrap_adapter_exec_methods m }
        else
          DEFAULT_EXEC_METHODS.each { |m| __wrap_adapter_exec_methods m }
        end
      end

      def around_connection_checkin(&block)
        callbacks = AdvancedConnection.callbacks.statement_pooling
        if callbacks.around.respond_to? :call
          callbacks.around.call() { block.call }
        end
      end

      def before_connection_checkin
        callbacks = AdvancedConnection.callbacks.statement_pooling
        callbacks.before.call if callbacks.before.respond_to? :call
      end

      def after_connection_checkin
        callbacks = AdvancedConnection.callbacks.statement_pooling
        callbacks.after.call if callbacks.after.respond_to? :call
      end
    end
  end
end
