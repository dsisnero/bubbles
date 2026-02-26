require "atomic"
require "math"
require "../tea"
require "lipgloss"

module Bubbles
  module Progress
    @@last_id = Atomic(Int64).new(0_i64)

    def self.next_id : Int32
      @@last_id.add(1).to_i32
    end

    DefaultFullCharHalfBlock = '▌'
    DefaultFullCharFullBlock = '█'
    DefaultEmptyCharBlock    = '░'

    FPS               =   60
    DEFAULT_WIDTH     =   40
    DEFAULT_FREQUENCY = 18.0
    DEFAULT_DAMPING   =  1.0

    DEFAULT_BLEND_START = "#5A56E0"
    DEFAULT_BLEND_END   = "#EE6FF8"
    DEFAULT_FULL_COLOR  = "#7571F9"
    DEFAULT_EMPTY_COLOR = "#606060"

    alias Color = String
    alias ColorFunc = Float64, Float64 -> Color
    alias Option = Proc(Model, Nil)

    def self.with_default_blend : Option
      with_colors(DEFAULT_BLEND_START, DEFAULT_BLEND_END)
    end

    def self.with_colors(*colors : Color) : Option
      if colors.empty?
        return ->(m : Model) do
          m.full_color = DEFAULT_FULL_COLOR
          m.blend = [] of Color
          m.color_func = nil
        end
      end

      if colors.size == 1
        return ->(m : Model) do
          m.full_color = colors[0]
          m.color_func = nil
          m.blend = [] of Color
        end
      end

      ->(m : Model) { m.blend = colors.to_a }
    end

    def self.with_color_func(fn : ColorFunc) : Option
      ->(m : Model) do
        m.color_func = fn
        m.blend = [] of Color
      end
    end

    def self.with_fill_characters(full : Char, empty : Char) : Option
      ->(m : Model) do
        m.full = full
        m.empty = empty
      end
    end

    def self.without_percentage : Option
      ->(m : Model) { m.show_percentage = false }
    end

    def self.with_width(w : Int32) : Option
      ->(m : Model) { m.set_width(w) }
    end

    def self.with_spring_options(frequency : Float64, damping : Float64) : Option
      ->(m : Model) do
        m.set_spring_options(frequency, damping)
        m.spring_customized = true
      end
    end

    def self.with_scaled(enabled : Bool) : Option
      ->(m : Model) { m.scale_blend = enabled }
    end

    class FrameMsg < Tea::Msg
      getter id : Int32
      getter tag : Int32

      def initialize(@id : Int32, @tag : Int32)
      end
    end

    class Model
      include Tea::Model

      property id : Int32
      property tag : Int32
      property width : Int32
      property full : Char
      property full_color : Color
      property empty : Char
      property empty_color : Color
      property show_percentage : Bool # ameba:disable Naming/QueryBoolMethods
      property percent_format : String
      property percentage_style : Lipgloss::Style
      property spring_frequency : Float64
      property spring_damping : Float64
      property spring_customized : Bool # ameba:disable Naming/QueryBoolMethods
      property percent_shown : Float64
      property target_percent : Float64
      property velocity : Float64
      property blend : Array(Color)
      property scale_blend : Bool # ameba:disable Naming/QueryBoolMethods
      property color_func : ColorFunc?

      def initialize
        @id = Progress.next_id
        @tag = 0
        @width = DEFAULT_WIDTH
        @full = DefaultFullCharHalfBlock
        @full_color = DEFAULT_FULL_COLOR
        @empty = DefaultEmptyCharBlock
        @empty_color = DEFAULT_EMPTY_COLOR
        @show_percentage = true
        @percent_format = " %3.0f%%"
        @percentage_style = Lipgloss::Style.new
        @spring_frequency = DEFAULT_FREQUENCY
        @spring_damping = DEFAULT_DAMPING
        @spring_customized = false
        @percent_shown = 0.0
        @target_percent = 0.0
        @velocity = 0.0
        @blend = [] of Color
        @scale_blend = false
        @color_func = nil
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
        unless m.spring_customized
          m.set_spring_options(DEFAULT_FREQUENCY, DEFAULT_DAMPING)
        end
        m
      end

      def init : Tea::Cmd
        nil
      end

      def update(msg : Tea::Msg) : {Model, Tea::Cmd}
        case msg
        when FrameMsg
          return {self, nil} if msg.id != @id || msg.tag != @tag
          return {self, nil} unless animating?

          # Damped spring-like integration for percent animation.
          delta = @target_percent - @percent_shown
          dt = 1.0 / FPS
          @velocity += delta * @spring_frequency * dt
          @velocity *= Math.exp(-@spring_damping * dt)
          @percent_shown = clamp(@percent_shown + @velocity, 0.0, 1.0)
          {self, next_frame}
        else
          {self, nil}
        end
      end

      def set_spring_options(frequency : Float64, damping : Float64)
        @spring_frequency = frequency
        @spring_damping = damping
      end

      def spring_options=(opts : Tuple(Float64, Float64))
        set_spring_options(opts[0], opts[1])
      end

      def percent : Float64
        @target_percent
      end

      def set_percent(p : Float64) : Tea::Cmd # ameba:disable Naming/AccessorMethodName
        @target_percent = clamp(p, 0.0, 1.0)
        @tag += 1
        next_frame
      end

      def percent=(p : Float64) : Tea::Cmd
        set_percent(p)
      end

      def incr_percent(v : Float64) : Tea::Cmd
        set_percent(percent + v)
      end

      def decr_percent(v : Float64) : Tea::Cmd
        set_percent(percent - v)
      end

      def view : String
        view_as(@percent_shown)
      end

      def view_as(percent : Float64) : String
        percent_view = percentage_view(percent)
        bar = bar_view(percent, Lipgloss.width(percent_view))
        bar + percent_view
      end

      def set_width(w : Int32) # ameba:disable Naming/AccessorMethodName
        @width = w
      end

      def width=(w : Int32)
        set_width(w)
      end

      def animating? : Bool
        dist = (@percent_shown - @target_percent).abs
        !(dist < 0.001 && @velocity.abs < 0.01)
      end

      private def next_frame : Tea::Cmd
        Tea::Cmds.tick((1000 // FPS).milliseconds) do
          FrameMsg.new(@id, @tag)
        end
      end

      private def bar_view(percent : Float64, text_width : Int32) : String
        tw = Math.max(0, @width - text_width)
        fw = (tw * clamp(percent, 0.0, 1.0)).round.to_i
        fw = Math.max(0, Math.min(tw, fw))

        # Color rendering is currently a no-op in Lipgloss; preserve fill math.
        full_part = @full.to_s * fw
        empty_part = @empty.to_s * Math.max(0, tw - fw)
        full_part + empty_part
      end

      private def percentage_view(percent : Float64) : String
        return "" unless @show_percentage
        p = clamp(percent, 0.0, 1.0)
        @percentage_style.inline(true).render(@percent_format % (p * 100))
      end

      private def clamp(v : Float64, lo : Float64, hi : Float64) : Float64
        return lo if v < lo
        return hi if v > hi
        v
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
