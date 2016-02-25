require 'singleton'

module AdvancedConnection
  class Config
    include Singleton

    VALID_QUEUE_TYPES = [ :fifo, :lifo, :prefer_younger, :prefer_older ]

    def initialize
      @loaded = false
      @config = {
        :transaction_encapsulation    => false,
        :idle_connection_reaping      => false,
        :connection_pool_prestart     => false,
        :connection_pool_queue_type   => :fifo,
        :without_connection_callbacks => {}.with_indifferent_access
      }.with_indifferent_access
    end

    class << self
      def method_missing(method, *args, &block)
        return super unless instance.respond_to? method
        instance.public_send(method, *args, &block)
      end

      def respond_to_missing?(method, include_private = false)
        instance.respond_to?(method) || super
      end
    end

    def loaded!
      @loaded = true
    end

    def loaded?
      @loaded
    end

    def [](key)
      @config[key.to_sym]
    end

    def []=(key, value)
      public_send("#{key}=", value)
    end

    def include?(key)
      @config.include? key.to_s.tr('=', '')
    end

    def to_h
      @config.dup
    end

    def transaction_encapsulation
      @config[:transaction_encapsulation]
    end

    def transaction_encapsulation=(value)
      @config[:transaction_encapsulation] = !!value
    end

    def idle_connection_reaping
      @config[:idle_connection_reaping]
    end

    def idle_connection_reaping=(value)
      @config[:idle_connection_reaping] = !!value
    end

    def connection_pool_prestart
      @config[:connection_pool_prestart]
    end

    def connection_pool_prestart=(value)
      unless value.nil? || value === false || value.is_a?(Fixnum) || value =~ /^\d+$/
        raise ConfigError, 'Expected connection_pool_prestart to be nil, false ' \
                           "or a valid positive integer, but found `#{value.inspect}`"
      end

      if value.to_s =~ /^\d+$/
        @config[:connection_pool_prestart] = value.to_i
      else
        @config[:connection_pool_prestart] = false
      end
    end

    def connection_pool_queue_type
      @config[:connection_pool_queue_type]
    end

    def connection_pool_queue_type=(value)
      unless value.is_a?(String) || value.is_a?(Symbol)
        raise ConfigError, 'Expected String or Symbol for connection_pool_queue_type ' \
                           "but found `#{value.class.name}`"
      end

      unless VALID_QUEUE_TYPES.include? value.to_sym
        raise ConfigError, 'Expected connection_pool_queue_type to be one of ' \
                           ':fifo, :lifo, :prefer_younger, or :prefer_older ' \
                           "but found `#{value.inspect}`"
      end
      @config[:connection_pool_queue_type] = value
    end

    def callbacks
      @config[:callbacks] ||= begin
        default_callbacks = {
          before_checkin:  nil, after_checkin:  nil,
          before_checkout: nil, after_checkout: nil,
        }
        ActiveSupport::OrderedOptions.new.tap do |callbacks|
          callbacks.without_connection = ActiveSupport::OrderedOptions.new
          callbacks.without_connection.checkin  = ActiveSupport::OrderedOptions.new
          callbacks.without_connection.checkout = ActiveSupport::OrderedOptions.new
          default_callbacks.merge(without_connection_callbacks).each do |callback, proc|
            if callback.to_s =~ /^(before|after)_(checkin|checkout)$/
              callbacks.without_connection[$2][$1] = proc
            end
          end
        end
      end
    end

    def without_connection_callbacks
      @config[:without_connection_callbacks]
    end

    def without_connection_callbacks=(value)
      unless value.is_a? Hash
        raise ConfigError, "without_connection callbacks must be a hash"
      end
      @config[:without_connection_callbacks] = value.with_indifferent_access
    end

  end
end