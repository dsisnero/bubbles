require "bubbletea"
require "lipgloss"
require "atomic"

module Bubbles
  module Spinner
    @@last_id = Atomic(Int64).new(0_i64)

    def self.next_id : Int32
      @@last_id.add(1).to_i32
    end

    struct SpinnerData
      property frames : Array(String)
      property fps : Time::Span

      def initialize(@frames : Array(String), @fps : Time::Span)
      end
    end

    Line      = SpinnerData.new(["|", "/", "-", "\\"], 100.milliseconds)
    Dot       = SpinnerData.new(["⣾ ", "⣽ ", "⣻ ", "⢿ ", "⡿ ", "⣟ ", "⣯ ", "⣷ "], 100.milliseconds)
    MiniDot   = SpinnerData.new(["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"], 83.milliseconds)
    Jump      = SpinnerData.new(["⢄", "⢂", "⢁", "⡁", "⡈", "⡐", "⡠"], 100.milliseconds)
    Pulse     = SpinnerData.new(["█", "▓", "▒", "░"], 125.milliseconds)
    Points    = SpinnerData.new(["∙∙∙", "●∙∙", "∙●∙", "∙∙●"], 142.milliseconds)
    Globe     = SpinnerData.new(["🌍", "🌎", "🌏"], 250.milliseconds)
    Moon      = SpinnerData.new(["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"], 125.milliseconds)
    Monkey    = SpinnerData.new(["🙈", "🙉", "🙊"], 333.milliseconds)
    Meter     = SpinnerData.new(["▱▱▱", "▰▱▱", "▰▰▱", "▰▰▰", "▰▰▱", "▰▱▱", "▱▱▱"], 142.milliseconds)
    Hamburger = SpinnerData.new(["☱", "☲", "☴", "☲"], 333.milliseconds)
    Ellipsis  = SpinnerData.new(["", ".", "..", "..."], 333.milliseconds)

    class TickMsg
      include Tea::Msg
      getter time : Time
      getter id : Int32
      getter tag : Int32

      def initialize(@time : Time, @id : Int32, @tag : Int32)
      end
    end

    class Model
      property spinner : SpinnerData
      property style : Lipgloss::Style
      property frame : Int32
      property id : Int32
      property tag : Int32

      def initialize
        @spinner = Line
        @style = Lipgloss::Style.new
        @frame = 0
        @id = Spinner.next_id
        @tag = 0
      end

      def update(msg : Tea::Msg) : {Model, Tea::Cmd}
        case msg
        when TickMsg
          if msg.id > 0 && msg.id != @id
            return {self, nil}
          end
          if msg.tag > 0 && msg.tag != @tag
            return {self, nil}
          end

          @frame += 1
          if @frame >= @spinner.frames.size
            @frame = 0
          end

          @tag += 1
          {self, tick(@id, @tag)}
        else
          {self, nil}
        end
      end

      def view : String
        if @frame >= @spinner.frames.size
          return "(error)"
        end
        @style.render(@spinner.frames[@frame])
      end

      def tick : Tea::Msg
        TickMsg.new(Time.local, @id, @tag)
      end

      private def tick(id : Int32, tag : Int32) : Tea::Cmd
        Tea.tick(@spinner.fps) do
          TickMsg.new(Time.local, id, tag)
        end
      end
    end

    alias Option = Proc(Model, Nil)

    def self.new : Model
      Model.new
    end

    def self.new(*opts : Option) : Model
      m = Model.new
      opts.each(&.call(m))
      m
    end

    def self.with_spinner(spinner : SpinnerData) : Option
      ->(m : Model) { m.spinner = spinner }
    end

    def self.with_style(style : Lipgloss::Style) : Option
      ->(m : Model) { m.style = style }
    end
  end
end
