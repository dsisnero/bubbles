require "bubbletea"
require "atomic"

module Bubbles
  module Stopwatch
    @@last_id = Atomic(Int64).new(0_i64)

    def self.next_id : Int32
      (@@last_id.add(1) + 1).to_i32
    end

    alias Option = Proc(Model, Nil)

    def self.with_interval(interval : Time::Span) : Option
      ->(m : Model) { m.interval = interval }
    end

    class TickMsg
      include Tea::Msg
      getter id : Int32
      getter tag : Int32

      def initialize(@id : Int32, @tag : Int32)
      end
    end

    class StartStopMsg
      include Tea::Msg
      getter id : Int32
      getter running : Bool # ameba:disable Naming/QueryBoolMethods

      def initialize(@id : Int32, @running : Bool)
      end
    end

    class ResetMsg
      include Tea::Msg
      getter id : Int32

      def initialize(@id : Int32)
      end
    end

    class Model
      property interval : Time::Span
      property id : Int32
      property tag : Int32
      property? running : Bool

      # Internal field matching Go's 'd' field
      @d : Time::Span = 0.seconds

      def initialize
        @interval = 1.second
        @id = Stopwatch.next_id
        @tag = 0
        @running = false
        @d = 0.seconds
      end

      def id : Int32
        @id
      end

      def elapsed : Time::Span
        @d
      end

      def running : Bool
        @running
      end

      def self.new : Model
        m = allocate
        m.initialize
        m
      end

      def self.new(*opts : Option) : Model
        m = allocate
        m.initialize
        opts.each(&.call(m))
        m
      end

      def init : Tea::Cmd?
        start
      end

      def start : Tea::Cmd?
        Tea.sequence(
          -> { StartStopMsg.new(@id, true).as(Tea::Msg?) },
          tick(@id, @tag, @interval)
        )
      end

      def stop : Tea::Cmd
        -> { StartStopMsg.new(@id, false).as(Tea::Msg?) }
      end

      def toggle : Tea::Cmd?
        return stop if running?
        start
      end

      def reset : Tea::Cmd
        -> { ResetMsg.new(@id).as(Tea::Msg?) }
      end

      def update(msg : Tea::Msg) : {Model, Tea::Cmd?}
        case msg
        when StartStopMsg
          return {self, nil.as(Tea::Cmd?)} if msg.id != @id
          @running = msg.running
        when ResetMsg
          return {self, nil.as(Tea::Cmd?)} if msg.id != @id
          @d = 0.seconds
        when TickMsg
          return {self, nil.as(Tea::Cmd?)} if !running? || msg.id != @id
          if msg.tag > 0 && msg.tag != @tag
            return {self, nil.as(Tea::Cmd?)}
          end

          @d += @interval
          @tag += 1
          return {self, tick(@id, @tag, @interval)}
        end

        {self, nil.as(Tea::Cmd?)}
      end

      def view : String
        @d.to_s
      end

      private def tick(id : Int32, tag : Int32, d : Time::Span) : Tea::Cmd
        Tea.tick(d) do
          TickMsg.new(id, tag)
        end
      end
    end

    def self.new : Model
      Model.new
    end

    def self.new(*opts : Option) : Model
      Model.new(*opts)
    end
  end
end
