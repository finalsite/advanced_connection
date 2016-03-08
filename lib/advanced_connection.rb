require 'active_record'
require 'active_support/concern'
require 'active_support/hash_with_indifferent_access'
require 'advanced_connection/version'
require 'singleton'
require 'logger'

module AdvancedConnection
  extend ActiveSupport::Autoload

  eager_autoload do
    autoload :ActiveRecordExt
    autoload :Config
    autoload :Error
  end

  class << self
    def to_h
      config.to_h
    end

    def configure(overwrite = true)
      return unless overwrite
      (yield config).tap {
        config.loaded!
      }
    end

    def config
      @config ||= Config.instance
    end

    def method_missing(method, *args, &block)
      return super unless config.respond_to? method
      config.public_send(method, *args, &block)
    end

    def respond_to_missing?(method, include_private = false)
      config.respond_to?(method) || super
    end
  end

  require 'advanced_connection/railtie' if defined?(Rails)
end
