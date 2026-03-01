require "bubbletea"
require "lipgloss"
require "atomic"

module Bubbles
  module Spinner
    @@last_id = Atomic(Int64).new(0_i64)

    def self.next_id : Int32
      @@last_id.add(1).to_i32
    end

    struct Spinner
      property frames : Array(String)
      property fps : Time::Span

      def initialize(@frames : Array(String), @fps : Time::Span)
      end
    end

    Line      = Spinner.new(["|", "/", "-", "\\"], 100.milliseconds)
    Dot       = Spinner.new(["⣾ ", "⣽ ", "⣻ ", "⢿ ", "⡿ ", "⣟ ", "⣯ ", "⣷ "], 100.milliseconds)
    MiniDot   = Spinner.new(["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"], 83.milliseconds)
    Jump      = Spinner.new(["⢄", "⢂", "⢁", "⡁", "⡈", "⡐", "⡠"], 100.milliseconds)
    Pulse     = Spinner.new(["█", "▓", "▒", "░"], 125.milliseconds)
    Points    = Spinner.new(["∙∙∙", "●∙∙", "∙●∙", "∙∙●"], 142.milliseconds)
    Globe     = Spinner.new(["🌍", "🌎", "🌏"], 250.milliseconds)
    Moon      = Spinner.new(["🌑", "🌒", "🌓", "🌔", "🌕", "🌖", "🌗", "🌘"], 125.milliseconds)
    Monkey    = Spinner.new(["🙈", "🙉", "🙊"], 333.milliseconds)
    Meter     = Spinner.new(["▱▱▱", "▰▱▱", "▰▰▱", "▰▰▰", "▰▰▱", "▰▱▱", "▱▱▱"], 142.milliseconds)
    Hamburger = Spinner.new(["☱", "☲", "☴", "☲"], 333.milliseconds)
    Ellipsis  = Spinner.new(["", ".", "..", "..."], 333.milliseconds)

    class TickMsg
      include Tea::Msg
      getter time : Time
      getter id : Int32
      getter tag : Int32

      def initialize(@time : Time, @id : Int32, @tag : Int32)
      end
    end

    class Model
      property spinner : Spinner
      property style : Lipgloss::Style
      property frame : Int32
      property id : Int32
      property tag : Int32

      def initialize
        @spinner = Line
        @style = Lipgloss::Style.new
        @frame = 0
        @id = Bubbles::Spinner.next_id
        @tag = 0
      end

      def dup : Model
        m = Model.new
        m.spinner = @spinner
        m.style = @style.dup
        m.frame = @frame
        m.id = @id
        m.tag = @tag
        m
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

          m = self.dup
          m.frame += 1
          if m.frame >= m.spinner.frames.size
            m.frame = 0
          end

          m.tag += 1
          {m, tick(m.id, m.tag)}
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

    def self.with_spinner(spinner : Spinner) : Option
      ->(m : Model) { m.spinner = spinner }
    end

    def self.with_style(style : Lipgloss::Style) : Option
      ->(m : Model) { m.style = style }
    end
  end
end
