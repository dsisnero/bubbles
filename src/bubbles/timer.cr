require "../tea"
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

    class StartStopMsg < Tea::Msg
      getter id : Int32
      getter running : Bool # ameba:disable Naming/QueryBoolMethods

      def initialize(@id : Int32, @running : Bool)
      end
    end

    class TickMsg < Tea::Msg
      getter id : Int32
      getter timeout : Bool # ameba:disable Naming/QueryBoolMethods
      getter tag : Int32

      def initialize(@id : Int32, @timeout : Bool, @tag : Int32)
      end
    end

    class TimeoutMsg < Tea::Msg
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

      def update(msg : Tea::Msg) : {Model, Tea::Cmd}
        case msg
        when StartStopMsg
          if msg.id != 0 && msg.id != @id
            return {self, nil}
          end
          @running = msg.running
          return {self, tick}
        when TickMsg
          if !running? || (msg.id != 0 && msg.id != @id)
            return {self, nil}
          end
          if msg.tag > 0 && msg.tag != @tag
            return {self, nil}
          end

          @timeout -= @interval
          return {self, Tea::Cmds.batch([tick, timedout_cmd].compact)}
        end

        {self, nil}
      end

      def view : String
        @timeout.to_s
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
        Tea::Cmds.tick(@interval) do
          TickMsg.new(@id, timedout?, @tag)
        end
      end

      private def timedout_cmd : Tea::Cmd
        return nil unless timedout?
        -> { TimeoutMsg.new(@id).as(Tea::Msg?) }
      end

      private def start_stop(v : Bool) : Tea::Cmd
        -> { StartStopMsg.new(@id, v).as(Tea::Msg?) }
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
