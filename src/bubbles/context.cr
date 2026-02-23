module Bubbles
  module Context
    class Error < Exception
      class DeadlineExceeded < Error; end

      class Canceled < Error; end
    end

    # Context represents a context that can be canceled or timed out.
    class Context
      @done : Channel(Nil)?
      @err : Error?

      # Returns a channel that is closed when the context is done.
      def done : Channel(Nil)
        @done ||= Channel(Nil).new
      end

      # Returns the error that caused the context to be done.
      def err : Error?
        @err
      end

      # Cancels the context with the given error.
      def cancel(err : Error? = nil)
        @err = err || Error::Canceled.new
        done.close
      end

      # Returns true if the context has been canceled or timed out.
      def done? : Bool
        done.closed?
      end
    end

    # CancelFunc is a function that cancels a context.
    alias CancelFunc = ->

    # Returns a background context that is never canceled.
    def self.background : Context
      BackgroundContext.instance
    end

    # Returns a new context that is canceled after the given duration.
    def self.with_timeout(parent : Context, duration : Time::Span) : {Context, CancelFunc}
      ctx = TimeoutContext.new(parent, duration)
      cancel = -> { ctx.cancel }
      {ctx, cancel}
    end

    private class BackgroundContext < Context
      def self.instance
        @@instance ||= new
      end
    end

    private class TimeoutContext < Context
      def initialize(parent : Context, @duration : Time::Span)
        spawn do
          select
          when timeout(@duration)
            cancel(Error::DeadlineExceeded.new)
          when parent.done.receive?
            cancel(parent.err)
          end
        end
      end

      private def timeout(duration : Time::Span) : Channel(Nil)
        ch = Channel(Nil).new
        spawn do
          sleep(duration)
          ch.close
        end
        ch
      end
    end
  end
end
