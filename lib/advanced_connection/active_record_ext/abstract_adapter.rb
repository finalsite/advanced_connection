require 'active_record/connection_adapters/abstract_adapter'

module AdvancedConnection::ActiveRecordExt
  module AbstractAdapter
    extend ActiveSupport::Autoload
    extend ActiveSupport::Concern

    eager_autoload do
      autoload :StatementPooling
    end

    included do
      attr_accessor :last_checked_in, :instantiated_at
      alias_method_chain :initialize, :advanced_connection
    end

    def initialize_with_advanced_connection(*args, &block)
      @last_checked_in = Time.now - 1.year
      @instantiated_at = Time.now
      initialize_without_advanced_connection(*args, &block)
    end

    def instance_age
      (Time.now - @instantiated_at).to_f
    end
  end
end