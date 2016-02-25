module AdvancedConnection
  class Error < StandardError
    class ConfigError < Error; end
  end
end