require 'yaml'
require 'erb'
require 'pathname'
require 'singleton'

require 'active_support/hash_with_indifferent_access'
require 'active_support/core_ext/hash/indifferent_access'
require 'active_support/core_ext/module/delegation'

module AdvancedConnection
  module Test
    class DbConfig
      include Singleton

      class << self
        def method_missing(method, *args)
          return super unless instance.respond_to? method
          if block_given?
            instance.public_send(method, *args) { yield }
          else
            instance.public_send(method, *args)
          end
        end

        def respond_to_missing?(method, include_private=false)
          instance.respond_to?(method) || super
        end
      end

      def initialize
        @config ||= begin
          config_path = Pathname.new(__FILE__).dirname.parent.join('config', 'database.yml.erb')
          YAML.load(ERB.new(IO.read(config_path), nil, '-').result)
        end
      end

      delegate :[], to: :connections
      delegate :each, to: :connections
      delegate :each_key, to: :connections
      delegate :keys, to: :connections

      def postgresql_config
        connections['postgresql']
      end

      def mysql_config
        connections['mysql']
      end

      def sqlite_config
        connections['sqlite']
      end

      private

        def connections
          @config['connections']
        end
    end
  end
end