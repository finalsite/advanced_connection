module AdvancedConnection::ActiveRecordExt
  module WithoutConnection
    extend ActiveSupport::Concern

    included do
      define_callbacks :without_connection_checkin, :without_connection_checkout
    end

    def without_connection
      return unless block_given?
      run_callbacks :without_connection_checkin do
        # return the connection to the pool for the duration of `yield`
        ActiveRecord::Base.connection_pool.checkin ActiveRecord::Base.connection
      end

      yield
    ensure
      tries = 3
      begin
        # make sure to retrieve another connection
        run_callbacks :without_connection_checkout do
          ActiveRecord::Base.connection
        end
      rescue ActiveRecord::ConnectionTimeoutError
        Rails.logger.info "Failed to acquire a connection (#{Thread.current.object_id}) trying #{tries > 1 ? "#{tries} more times" : 'once more'}"
        retry unless (tries -= 1) < 0
        Rails.logger.info "Giving up on trying to acquire another connection"
        raise
      end
    end
  end
end