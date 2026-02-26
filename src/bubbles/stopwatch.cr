require "../tea"
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

    class TickMsg < Tea::Msg
      getter id : Int32
      getter tag : Int32

      def initialize(@id : Int32, @tag : Int32)
      end
    end

    class StartStopMsg < Tea::Msg
      getter id : Int32
      getter running : Bool # ameba:disable Naming/QueryBoolMethods

      def initialize(@id : Int32, @running : Bool)
      end
    end

    class ResetMsg < Tea::Msg
      getter id : Int32

      def initialize(@id : Int32)
      end
    end

    class Model
      property interval : Time::Span
      property id : Int32
      property tag : Int32
      property? running : Bool
      property elapsed : Time::Span

      def initialize
        @interval = 1.second
        @id = Stopwatch.next_id
        @tag = 0
        @running = false
        @elapsed = 0.seconds
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

      def init : Tea::Cmd
        start
      end

      def start : Tea::Cmd
        @running = true
        tick(@id, @tag, @interval)
      end

      def stop : Tea::Cmd
        -> { StartStopMsg.new(@id, false).as(Tea::Msg?) }
      end

      def toggle : Tea::Cmd
        return stop if running?
        start
      end

      def reset : Tea::Cmd
        -> { ResetMsg.new(@id).as(Tea::Msg?) }
      end

      def update(msg : Tea::Msg) : {Model, Tea::Cmd}
        case msg
        when StartStopMsg
          return {self, nil} if msg.id != @id
          @running = msg.running
        when ResetMsg
          return {self, nil} if msg.id != @id
          @elapsed = 0.seconds
        when TickMsg
          return {self, nil} if !running? || msg.id != @id
          if msg.tag > 0 && msg.tag != @tag
            return {self, nil}
          end

          @elapsed += @interval
          @tag += 1
          return {self, tick(@id, @tag, @interval)}
        end

        {self, nil}
      end

      def view : String
        @elapsed.to_s
      end

      private def tick(id : Int32, tag : Int32, d : Time::Span) : Tea::Cmd
        Tea::Cmds.tick(d) do
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
