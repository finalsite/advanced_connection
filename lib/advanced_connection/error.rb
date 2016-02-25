module AdvancedConnection
  class Error < StandardError
    class ConfigError < Error; end
    class UnableToReleaseConnection < Error; end
  end
end