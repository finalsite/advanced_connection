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

      MAX_REAQUIRE_ATTEMPTS = 3

      included do
        include ::ActiveSupport::Callbacks
        alias_method :retrieve_connection, :connection

        define_callbacks :without_connection
        set_callback :without_connection, :around, :around_without_connection
        set_callback :without_connection, :before, :before_without_connection
        set_callback :without_connection, :after, :after_without_connection
      end

      def without_connection(&block)
        return unless block_given?

        # if we're not enabled just execute the block and return
        return block.call unless AdvancedConnection.enable_without_connection

        # if we have a transaction open, we can't release the database connection
        # or Bad Things (tm) happen - so we just execute our block and return
        if transaction_open?
          Rails.logger.warn "WithoutConnection skipped due to open transaction."
          return block.call
        end

        if AdvancedConnection.callbacks.without_connection.present?
          run_callbacks(:without_connection) do
            __without_connection { block.call }
          end
        else
          __without_connection { block.call }
        end
      end

    private

      def __without_connection
        # return the connection to the pool for the duration of `yield`
        release_connection if active_connection?
        raise Error::UnableToReleaseConnection if active_connection?
        yield
      ensure
        attempt = 0
        begin
          # attempt to retrieve another connection
          retrieve_connection
        rescue ActiveRecord::ConnectionTimeoutError
          if attempt >= MAX_REAQUIRE_ATTEMPTS
            Rails.logger.info "Giving up on trying to reacquire database connection"
            raise Error::UnableToReaquireConnection
          else
            Rails.logger.warn "Failed to reaquire database connection - reattempt #{attempt += 1}/#{MAX_REAQUIRE_ATTEMPTS} ..."
          end

          retry
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
