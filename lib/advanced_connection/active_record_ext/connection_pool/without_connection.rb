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
module AdvancedConnection::ActiveRecordExt
  module ConnectionPool
    module WithoutConnection
      extend ActiveSupport::Concern

      included do
        include ::ActiveSupport::Callbacks
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
            __without_connection do
              yield
            end
          end
        else
          __without_connection do
            yield
          end
        end
      end

    private

      def __without_connection
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

      def around_without_connection
        callbacks = AdvancedConnection.callbacks.without_connection
        callbacks.around.call do
          yield
        end if callbacks.around.respond_to? :call
      end

      def before_without_connection
        callbacks = AdvancedConnection.callbacks.without_connection
        callbacks.before.call if callbacks.before.respond_to? :call
      end

      def after_without_connection
        callbacks = AdvancedConnection.callbacks.without_connection
        callbacks.after.call if callbacks.after.respond_to? :call
      end
    end
  end
end
