require 'singleton'

module AdvancedConnection
  class Config
    include Singleton

    VALID_QUEUE_TYPES = [
      :fifo, :lifo, :stack, :prefer_younger, :prefer_older
    ].freeze unless defined? VALID_QUEUE_TYPES

    CALLBACK_TYPES = ActiveSupport::OrderedOptions.new.merge({
      before: nil,
      around: nil,
      after: nil
    }).freeze unless defined? CALLBACK_TYPES

    DEFAULT_CONFIG = ActiveSupport::OrderedOptions.new.merge({
      :enable_without_connection      => false,
      :enable_statement_pooling       => false,
      :enable_idle_connection_manager => false,
      :connection_pool_queue_type     => :fifo,
      :warmup_connections             => false,
      :min_idle_connections           => 0,
      :max_idle_connections           => ::Float::INFINITY,
      :max_idle_time                  => 0,
      :idle_check_interval            => 0,
      :callbacks                      => ActiveSupport::OrderedOptions.new
    }).freeze unless defined? DEFAULT_CONFIG

    class << self
      def method_missing(method, *args, &block)
        return super unless instance.include?(method) || instance.respond_to?(method)
        instance.public_send(method, *args, &block)
      end

      def respond_to_missing?(method, include_private = false)
        instance.respond_to?(method) || super
      end

      def include?(key)
        instance.include?(key) || super
      end

      def add_callback(*names)
        Array(names).flatten.each { |name|
          class_eval(<<-EOS, __FILE__, __LINE__ + 1)
            def #{name}_callbacks
              @config.callbacks.#{name} ||= CALLBACK_TYPES.dup
            end

            def #{name}_callbacks=(value)
              if not value.is_a? Hash
                fail Error::ConfigError, "#{name} callbacks must be a hash"
              elsif (bad_options = (value.keys.collect(&:to_sym) - CALLBACK_TYPES.keys)).size > 0
                plural = bad_options .size > 1 ? 's' : ''
                fail Error::ConfigError, "Unexpected callback option\#{plural}: " \
                                         " `\#{bad_options.join('`, `')}`"
              elsif (uncallable = value.select { |k,v| !v.respond_to? :call }).present?
                plural = uncallable.size > 1 ? 's' : ''
                fail Error::ConfigError, "Expected #{name} callback\#{plural}" \
                                         " `\#{uncallable.keys.join('`, `')}` to be callable"
              end

              @config.callbacks.#{name} = CALLBACK_TYPES.merge(value)
            end
          EOS
          DEFAULT_CONFIG.callbacks[name.to_sym] = CALLBACK_TYPES.dup
        }
      end
      alias_method :add_callbacks, :add_callback
    end

    add_callbacks :without_connection, :statement_pooling

    def initialize
      @loaded = false
      @config = DEFAULT_CONFIG.deep_dup
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
      public_send("#{key}=".to_sym, value)
    end

    def include?(key)
      @config.include? key.to_s.tr('=', '').to_sym
    end

    def to_h
      @config.dup
    end

    def callbacks
      @config.callbacks
    end

    def enable_without_connection
      @config[:enable_without_connection]
    end

    def enable_without_connection=(value)
      if enable_statement_pooling && !!value
        raise Error::ConfigError, "WithoutConnection blocks conflict with Statement Pooling feature"
      end
      @config[:enable_without_connection] = !!value
    end

    def enable_statement_pooling
      @config[:enable_statement_pooling]
    end

    def enable_statement_pooling=(value)
      if enable_without_connection && !!value
        raise Error::ConfigError, "Statement Pooling conflicts with WithoutConnection feature"
      end
      @config[:enable_statement_pooling] = !!value
    end

    def enable_idle_connection_manager
      @config[:enable_idle_connection_manager]
    end

    def enable_idle_connection_manager=(value)
      @config[:enable_idle_connection_manager] = !!value
    end

    def warmup_connections
      @config[:warmup_connections]
    end

    def warmup_connections=(value)
      unless value.nil? || value === false || value.is_a?(Fixnum) || value =~ /^\d+$/
        fail Error::ConfigError, 'Expected warmup_connections to be nil, false ' \
                           "or a valid positive integer, but found `#{value.inspect}`"
      end

      if value.to_s =~ /^\d+$/
        @config[:warmup_connections] = value.to_i
      else
        @config[:warmup_connections] = false
      end
    end

    def min_idle_connections
      @config[:min_idle_connections]
    end

    def min_idle_connections=(value)
      unless value.is_a?(Numeric) || value =~ /^\d+$/
        fail Error::ConfigError, 'Expected min_idle_connections to be ' \
                           "a valid integer value, but found `#{value.inspect}`"
      end
      @config[:min_idle_connections] = value.to_i
    end

    def max_idle_connections
      @config[:max_idle_connections]
    end

    def max_idle_connections=(value)
      unless value.is_a?(Numeric) || value =~ /^\d+$/
        fail Error::ConfigError, 'Expected max_idle_connections to be ' \
                           "a valid integer value, but found `#{value.inspect}`"
      end
      @config[:max_idle_connections] = begin
        value.to_i
      rescue FloatDomainError => e
        raise unless e.message =~ /infinity/i
        ::Float::INFINITY
      end
    end

    def max_idle_time
      @config[:max_idle_time]
    end

    def max_idle_time=(value)
      unless value.is_a?(Numeric) || value =~ /^\d+$/
        fail Error::ConfigError, 'Expected max_idle_time to be ' \
                           "a valid integer value, but found `#{value.inspect}`"
      end
      @config[:max_idle_time] = value.to_i
    end

    def idle_check_interval
      @config[:idle_check_interval]
    end

    def idle_check_interval=(value)
      unless value.is_a?(Numeric) || value =~ /^\d+$/
        fail Error::ConfigError, 'Expected idle_check_interval to be ' \
                           "a valid integer value, but found `#{value.inspect}`"
      end
      @config[:idle_check_interval] = value.to_i
    end

    def connection_pool_queue_type
      @config[:connection_pool_queue_type]
    end

    def connection_pool_queue_type=(value)
      unless value.is_a?(String) || value.is_a?(Symbol)
        fail Error::ConfigError, 'Expected String or Symbol for connection_pool_queue_type ' \
                           "but found `#{value.class.name}`"
      end

      unless VALID_QUEUE_TYPES.include? value.to_sym
        fail Error::ConfigError, 'Expected connection_pool_queue_type to be one of ' \
                           ':fifo, :lifo, :stack, :prefer_younger, or :prefer_older ' \
                           "but found `#{value.inspect}`"
      end
      @config[:connection_pool_queue_type] = value
    end
  end
end