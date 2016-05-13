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

    def idle_time
      (in_use? ? 0.0 : Time.now - @last_checked_in).to_f
    end

    def idle?
      idle_time > pool.max_idle_time
    end

    def <=>(other)
      case pool.queue_type
        when :prefer_younger then
          # when prefering younger, we sort oldest->youngest
          # this ensures that older connections will be culled
          # during #remove_idle_connections()
          -(instance_age <=> other.instance_age)
        when :prefer_older then
          # when prefering older, we sort youngest->oldest
          # this ensures that younger connections will be culled
          # during #remove_idle_connections()
          (instance_age <=> other.instance_age)
        else
          # with fifo / lifo queues, we only care about the
          # last time a given connection was used (inferred
          # by when it was last checked into the pool).
          # This ensures that the longer idling connections
          # will be culled.
          -(last_checked_in <=> other.last_checked_in)
      end
    end
  end
end
