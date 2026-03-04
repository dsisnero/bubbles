{% if file_exists?("#{__DIR__}/../../../../src/bubbletea.cr") %}
  require "../../../../src/bubbletea"
{% else %}
  require "bubbletea"
{% end %}
require "atomic"

module Bubbles
  module Timer
    @@last_id = Atomic(Int64).new(0_i64)

    def self.next_id : Int32
      (@@last_id.add(1) + 1).to_i32
    end

    alias Option = Proc(Model, Nil)

    def self.with_interval(interval : Time::Span) : Option
      ->(m : Model) { m.interval = interval }
    end

    class StartStopMsg
      include Tea::Msg
      getter id : Int32
      getter running : Bool # ameba:disable Naming/QueryBoolMethods

      def initialize(@id : Int32, @running : Bool)
      end
    end

    class TickMsg
      include Tea::Msg
      getter id : Int32
      getter timeout : Bool # ameba:disable Naming/QueryBoolMethods
      getter tag : Int32

      def initialize(@id : Int32, @timeout : Bool, @tag : Int32)
      end
    end

    class TimeoutMsg
      include Tea::Msg
      getter id : Int32

      def initialize(@id : Int32)
      end
    end

    class Model
      property timeout : Time::Span
      property interval : Time::Span
      property id : Int32
      property tag : Int32
      property? running : Bool

      def initialize(@timeout : Time::Span)
        @interval = 1.second
        @id = Timer.next_id
        @tag = 0
        @running = true
      end

      def self.new(timeout : Time::Span, *opts : Option) : Model
        m = allocate
        m.initialize(timeout)
        opts.each(&.call(m))
        m
      end

      def running? : Bool
        !(timedout? || !@running)
      end

      def timedout? : Bool
        @timeout <= 0.seconds
      end

      def timedout : Bool
        timedout?
      end

      def init : Tea::Cmd
        tick
      end

      def update(msg : Tea::Msg) : {Model, Tea::Cmd?}
        case msg
        when StartStopMsg
          if msg.id != 0 && msg.id != @id
            return {self, nil.as(Tea::Cmd?)}
          end
          @running = msg.running
          return {self, tick}
        when TickMsg
          if !running? || (msg.id != 0 && msg.id != @id)
            return {self, nil.as(Tea::Cmd?)}
          end
          if msg.tag > 0 && msg.tag != @tag
            return {self, nil.as(Tea::Cmd?)}
          end

          @timeout -= @interval
          # Call batch with commands
          if cmd = timedout_cmd
            return {self, Tea.batch(tick.as(Tea::Cmd?), cmd)}
          else
            return {self, tick}
          end
        end

        {self, nil.as(Tea::Cmd?)}
      end

      def view : String
        format_duration(@timeout)
      end

      def start : Tea::Cmd
        start_stop(true)
      end

      def stop : Tea::Cmd
        start_stop(false)
      end

      def toggle : Tea::Cmd
        start_stop(!running?)
      end

      private def tick : Tea::Cmd
        Tea.tick(@interval) do
          TickMsg.new(@id, timedout?, @tag)
        end
      end

      private def timedout_cmd : Tea::Cmd?
        return nil.as(Tea::Cmd?) unless timedout?
        -> { TimeoutMsg.new(@id).as(Tea::Msg?) }
      end

      private def start_stop(v : Bool) : Tea::Cmd
        -> { StartStopMsg.new(@id, v).as(Tea::Msg?) }
      end

      private def format_duration(duration : Time::Span) : String
        ns = duration.total_nanoseconds.to_i64
        return "0s" if ns == 0

        sign = ""
        if ns < 0
          sign = "-"
          ns = -ns
        end

        second_ns = 1_000_000_000_i64
        minute_ns = 60_i64 * second_ns
        hour_ns = 60_i64 * minute_ns

        if ns < second_ns
          if ns % 1_000_000_i64 == 0
            return "#{sign}#{ns // 1_000_000_i64}ms"
          elsif ns % 1_000_i64 == 0
            return "#{sign}#{ns // 1_000_i64}us"
          else
            return "#{sign}#{ns}ns"
          end
        end

        hours = ns // hour_ns
        ns -= hours * hour_ns
        minutes = ns // minute_ns
        ns -= minutes * minute_ns
        seconds = ns // second_ns
        ns -= seconds * second_ns

        io = String::Builder.new
        io << sign
        io << hours << 'h' if hours > 0
        io << minutes << 'm' if minutes > 0 || hours > 0
        io << seconds
        if ns > 0
          frac = ns.to_s.rjust(9, '0').rstrip('0')
          io << '.' << frac
        end
        io << 's'
        io.to_s
      end
    end

    def self.new(timeout : Time::Span) : Model
      Model.new(timeout)
    end

    def self.new(timeout : Time::Span, *opts : Option) : Model
      Model.new(timeout, *opts)
    end
  end
end
