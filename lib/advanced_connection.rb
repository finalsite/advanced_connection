require 'active_record'
require 'active_support/concern'
require 'active_support/hash_with_indifferent_access'
require 'singleton'
require 'logger'

module AdvancedConnection
  extend ActiveSupport::Concern
  extend ActiveSupport::Autoload

  eager_autoload do
    autoload :ActiveRecordExt
    autoload :Config
    autoload :Error
  end

  autoload :VERSION

  included do
    include ActiveRecordExt
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
      if method.to_s.include?('=')
        config[method.to_s.tr('=', '')] = args.first
      elsif config.include? method
        config[method]
      else
        super
      end
    end

    def respond_to_missing?(method, include_private = false)
      config.include?(method) || super
    end
  end

  require 'advanced_connection/railtie' if defined?(Rails)
end
