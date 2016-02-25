module AdvancedConnection::ActiveRecordExt
  module ConnectionPool
    module WithoutConnection
      extend ActiveSupport::Concern

      included do
        alias_method :retrieve_connection, :connection
        define_callbacks :without_connection
        set_callback :without_connection, :around, :around_without_connection
        set_callback :without_connection, :before, :before_without_connection
        set_callback :without_connection, :after, :after_without_connection
      end

      def without_connection
        return unless block_given?

        if AdvancedConnection.callbacks.without_connection.present?
          run_callbacks(:without_connection) do
            __without_connection() { yield }
          end
        else
          __without_connection() { yield }
        end
      end

    private

      def __without_connection
        begin
          # return the connection to the pool for the duration of `yield`
          release_connection if active_connection?
          raise Error::UnableToReleaseConnection if active_connection?
          yield
        ensure
          tries = 3
          begin
            # attempt to retrieve another connection
            retrieve_connection
          rescue ActiveRecord::ConnectionTimeoutError
            Rails.logger.info "Failed to acquire a connection (#{Thread.current.object_id}) trying #{tries > 1 ? "#{tries} more times" : 'once more'}"
            retry unless (tries -= 1) < 0
            Rails.logger.info "Giving up on trying to acquire another connection"
            raise
          end
        end
      end

      def around_without_connection(&block)
        callbacks = AdvancedConnection.callbacks.without_connection
        if callbacks.around.respond_to? :call
          callbacks.around.call() {
            block.call
          }
        end
      end

      def before_without_connection
        callbacks = AdvancedConnection.callbacks.without_connection
        if callbacks.before.respond_to? :call
          callbacks.before.call
        end
      end

      def after_without_connection
        callbacks = AdvancedConnection.callbacks.without_connection
        if callbacks.after.respond_to? :call
          callbacks.after.call
        end
      end
    end
  end
end