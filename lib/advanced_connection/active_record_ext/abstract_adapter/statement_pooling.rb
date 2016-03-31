#
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
require 'active_record/connection_adapters/abstract_adapter'

module AdvancedConnection::ActiveRecordExt
  module AbstractAdapter
    module StatementPooling
      extend ActiveSupport::Concern

      module ExecuteWrapper
        def __wrap_adapter_exec_methods(*methods)
          Array(methods).flat_map(&:to_sym).each do |exec_method|
            class_eval(<<-EOS, __FILE__, __LINE__ + 1)
              def #{exec_method}_with_callback(sql, *args, &block)
                if Thread.current[:without_callbacks] || sql =~ /^BEGIN/i || transaction_open? || pool.nil?
                  #{exec_method}_without_callback(sql, *args, &block)
                else
                  run_callbacks(:statement_pooling_connection_checkin) do
                    #{exec_method}_without_callback(sql, *args, &block).tap {
                      reset!
                      pool.release_connection
                    }
                  end
                end
              end
            EOS
            alias_method_chain exec_method, :callback
          end
        end
        alias_method :__wrap_adapter_exec_method, :__wrap_adapter_exec_methods

        def __wrap_without_callbacks(*methods)
          Array(methods).flat_map(&:to_sym).each do |exec_method|
            target, punctuation = exec_method.to_s.sub(/([?!=])$/, ''), $1
            class_eval(<<-EOS, __FILE__, __LINE__ + 1)
              def #{target}_with_no_callbacks#{punctuation}(*args, &block)
                Thread.current[:without_callbacks] = true
                #{target}_without_no_callbacks#{punctuation}(*args, &block)
              ensure
                Thread.current[:without_callbacks] = nil
              end
            EOS
            alias_method_chain exec_method, :no_callbacks
          end
        end
        alias_method :__wrap_without_callback, :__wrap_without_callbacks
      end

      included do
        include ::ActiveSupport::Callbacks
        extend ExecuteWrapper

        define_callbacks :statement_pooling_connection_checkin
        set_callback :statement_pooling_connection_checkin, :around, :around_connection_checkin
        set_callback :statement_pooling_connection_checkin, :before, :before_connection_checkin
        set_callback :statement_pooling_connection_checkin, :after, :after_connection_checkin

        DEFAULT_EXEC_METHODS = [ :execute, :exec_no_cache, :query ].freeze
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
          JDBC_EXEC_METHODS.each { |exec_method| __wrap_adapter_exec_methods exec_method }
        else
          DEFAULT_EXEC_METHODS.each { |exec_method| __wrap_adapter_exec_methods exec_method }
        end

        [ :active?, :reset!, :disconnect!, :reconnect! ].each { |exec_method|
          __wrap_without_callbacks exec_method
        }
      end

      def around_connection_checkin
        callbacks = AdvancedConnection.callbacks.statement_pooling
        callbacks.around.call do
          yield
        end if callbacks.around.respond_to? :call
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
