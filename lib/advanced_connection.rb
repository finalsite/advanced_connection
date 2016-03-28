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
      (yield config).tap { config.loaded! }
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
