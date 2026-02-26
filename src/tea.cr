module Tea
  # Msg is the base type for all messages in the Bubble Tea architecture.
  abstract class Msg
  end

  # KeyPressMsg represents a key press event.
  class KeyPressMsg < Msg
    property key : String

    def initialize(@key : String)
    end

    # String returns the string representation of the key.
    def to_s : String
      @key
    end
  end

  # FocusMsg indicates that a component has received focus.
  class FocusMsg < Msg
  end

  # BlurMsg indicates that a component has lost focus.
  class BlurMsg < Msg
  end

  # Cmd is a command that produces a Msg. In Bubble Tea, commands are
  # asynchronous operations that eventually produce messages.
  # Nil is also a valid command meaning "no command".
  alias Cmd = Proc(Msg?) | Nil

  # Model is the interface that all Bubble Tea models must implement.
  module Model
    # Init returns the initial command(s) for the model.
    abstract def init : Cmd

    # Update handles incoming messages and returns an updated model
    # along with optional commands.
    abstract def update(msg : Msg) : {self, Cmd}

    # View renders the model's current state as a string for display.
    abstract def view : String
  end

  # Cmds provides helper functions for creating commands.
  module Cmds
    # Returns a command that does nothing.
    def self.none : Cmd
      -> { nil.as(Msg?) }
    end

    # Returns a command that produces the given message.
    def self.message(msg : Msg) : Cmd
      -> { msg }
    end

    # Returns a command that produces a message after a delay.
    # The block is called when the tick expires to produce the message.
    def self.tick(delay : Time::Span, &block : -> Msg) : Cmd
      -> {
        sleep(delay)
        block.call.as(Msg?)
      }
    end

    # Returns a command that batches multiple commands together.
    def self.batch(cmds : Array(Cmd)) : Cmd
      -> {
        cmds.each do |cmd|
          cmd.call
        end
        nil.as(Msg?)
      }
    end
  end
end
