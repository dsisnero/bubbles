require "../tea"
require "./key"
require "ansi"
require "lipgloss"

module Bubbles
  module Viewport
    DEFAULT_HORIZONTAL_STEP = 6

    alias Option = Proc(Model, Nil)

    def self.with_width(w : Int32) : Option
      ->(m : Model) { m.set_width(w) }
    end

    def self.with_height(h : Int32) : Option
      ->(m : Model) { m.set_height(h) }
    end

    struct KeyMap
      property page_down : Bubbles::Key::Binding
      property page_up : Bubbles::Key::Binding
      property half_page_up : Bubbles::Key::Binding
      property half_page_down : Bubbles::Key::Binding
      property down : Bubbles::Key::Binding
      property up : Bubbles::Key::Binding
      property left : Bubbles::Key::Binding
      property right : Bubbles::Key::Binding

      def initialize(
        @page_down = Bubbles::Key::Binding.new,
        @page_up = Bubbles::Key::Binding.new,
        @half_page_up = Bubbles::Key::Binding.new,
        @half_page_down = Bubbles::Key::Binding.new,
        @down = Bubbles::Key::Binding.new,
        @up = Bubbles::Key::Binding.new,
        @left = Bubbles::Key::Binding.new,
        @right = Bubbles::Key::Binding.new,
      )
      end
    end

    def self.default_key_map : KeyMap
      KeyMap.new(
        page_down: Bubbles::Key.new_binding(Bubbles::Key.with_keys("pgdown", "space", "f")),
        page_up: Bubbles::Key.new_binding(Bubbles::Key.with_keys("pgup", "b")),
        half_page_up: Bubbles::Key.new_binding(Bubbles::Key.with_keys("u", "ctrl+u")),
        half_page_down: Bubbles::Key.new_binding(Bubbles::Key.with_keys("d", "ctrl+d")),
        up: Bubbles::Key.new_binding(Bubbles::Key.with_keys("up", "k")),
        down: Bubbles::Key.new_binding(Bubbles::Key.with_keys("down", "j")),
        left: Bubbles::Key.new_binding(Bubbles::Key.with_keys("left", "h")),
        right: Bubbles::Key.new_binding(Bubbles::Key.with_keys("right", "l"))
      )
    end

    struct GutterContext
      property index : Int32
      property total_lines : Int32
      property soft : Bool # ameba:disable Naming/QueryBoolMethods

      def initialize(@index : Int32 = 0, @total_lines : Int32 = 0, @soft : Bool = false)
      end
    end

    alias GutterFunc = GutterContext -> String

    NoGutter = ->(_ctx : GutterContext) { "" }

    class Model
      property key_map : KeyMap
      property? soft_wrap : Bool
      property? fill_height : Bool
      property? mouse_wheel_enabled : Bool
      property mouse_wheel_delta : Int32
      property y_position : Int32
      property left_gutter_func : GutterFunc

      @width : Int32
      @height : Int32
      @y_offset : Int32
      @x_offset : Int32
      @horizontal_step : Int32
      @lines : Array(String)
      @longest_line_width : Int32
      @highlight_indices : Array(Int32)
      @hi_idx : Int32

      def initialize
        @width = 0
        @height = 0
        @key_map = Viewport.default_key_map
        @soft_wrap = false
        @fill_height = false
        @mouse_wheel_enabled = true
        @mouse_wheel_delta = 3
        @y_offset = 0
        @x_offset = 0
        @horizontal_step = DEFAULT_HORIZONTAL_STEP
        @y_position = 0
        @left_gutter_func = NoGutter
        @lines = [] of String
        @longest_line_width = 0
        @highlight_indices = [] of Int32
        @hi_idx = 0
      end

      def self.new(*opts : Option) : Model
        m = allocate
        m.initialize
        opts.each(&.call(m))
        m
      end

      def init : Tea::Cmd
        nil
      end

      def height : Int32
        @height
      end

      def set_height(h : Int32) # ameba:disable Naming/AccessorMethodName
        @height = h
      end

      def height=(h : Int32)
        set_height(h)
      end

      def width : Int32
        @width
      end

      def set_width(w : Int32) # ameba:disable Naming/AccessorMethodName
        @width = w
      end

      def width=(w : Int32)
        set_width(w)
      end

      def at_top : Bool
        y_offset <= 0
      end

      def at_bottom : Bool
        y_offset >= max_y_offset
      end

      def past_bottom : Bool
        y_offset > max_y_offset
      end

      def scroll_percent : Float64
        total = total_line_count
        return 1.0 if height >= total
        v = y_offset.to_f / (total - height).to_f
        clampf(v, 0.0, 1.0)
      end

      def horizontal_scroll_percent : Float64
        return 1.0 if @x_offset >= @longest_line_width - width
        v = @x_offset.to_f / (@longest_line_width - width).to_f
        clampf(v, 0.0, 1.0)
      end

      def set_content(s : String) # ameba:disable Naming/AccessorMethodName
        set_content_lines(s.split('\n'))
      end

      def content=(s : String)
        set_content(s)
      end

      def set_content_lines(lines : Array(String)) # ameba:disable Naming/AccessorMethodName
        @lines = lines.dup

        if @lines.size == 1 && Ansi.string_width(@lines[0]) == 0
          @lines = [] of String
        else
          normalized = [] of String
          @lines.each do |line|
            line = line.gsub("\r\n", "\n")
            if line.includes?('\n')
              line.split('\n').each { |part| normalized << part }
            else
              normalized << line
            end
          end
          @lines = normalized
        end

        @longest_line_width = @lines.max_of? { |line| Ansi.string_width(line) } || 0
        clear_highlights
        goto_bottom if y_offset > max_y_offset
      end

      def content_lines=(lines : Array(String))
        set_content_lines(lines)
      end

      def get_content : String # ameba:disable Naming/AccessorMethodName
        @lines.join("\n")
      end

      def content : String
        get_content
      end

      def total_line_count : Int32
        @lines.size
      end

      def visible_line_count : Int32
        visible_lines.size
      end

      def y_offset : Int32
        @y_offset
      end

      def x_offset : Int32
        @x_offset
      end

      def set_y_offset(y : Int32) # ameba:disable Naming/AccessorMethodName
        @y_offset = clamp(y, 0, max_y_offset)
      end

      def y_offset=(y : Int32)
        set_y_offset(y)
      end

      def set_x_offset(x : Int32) # ameba:disable Naming/AccessorMethodName
        return if @soft_wrap
        @x_offset = clamp(x, 0, max_x_offset)
      end

      def x_offset=(x : Int32)
        set_x_offset(x)
      end

      def set_horizontal_step(step : Int32) # ameba:disable Naming/AccessorMethodName
        @horizontal_step = Math.max(0, step)
      end

      def horizontal_step=(step : Int32)
        set_horizontal_step(step)
      end

      def scroll_up(lines : Int32)
        set_y_offset(@y_offset - lines)
      end

      def scroll_down(lines : Int32)
        set_y_offset(@y_offset + lines)
      end

      def scroll_left(cols : Int32)
        set_x_offset(@x_offset - cols)
      end

      def scroll_right(cols : Int32)
        set_x_offset(@x_offset + cols)
      end

      def goto_top
        @y_offset = 0
      end

      def goto_bottom
        @y_offset = max_y_offset
      end

      def ensure_visible(line_idx : Int32)
        if line_idx < @y_offset
          @y_offset = line_idx
        elsif line_idx >= @y_offset + @height
          @y_offset = line_idx - @height + 1
        end
        set_y_offset(@y_offset)
      end

      def set_highlights(matches : Array(Array(Int32))) # ameba:disable Naming/AccessorMethodName
        @highlight_indices = matches.map { |match| match[0] }.to_a
        @hi_idx = 0
      end

      def highlights=(matches : Array(Array(Int32)))
        set_highlights(matches)
      end

      def clear_highlights
        @highlight_indices.clear
        @hi_idx = 0
      end

      def highlight_next
        return if @highlight_indices.empty?
        @hi_idx = (@hi_idx + 1) % @highlight_indices.size
        ensure_visible(@highlight_indices[@hi_idx])
      end

      def highlight_previous
        return if @highlight_indices.empty?
        @hi_idx = (@hi_idx - 1) % @highlight_indices.size
        ensure_visible(@highlight_indices[@hi_idx])
      end

      def view : String
        return "" if @width <= 0 || @height <= 0
        content = visible_lines.join("\n")
        Lipgloss.new_style.width(@width).height(@height).render(content)
      end

      private def visible_lines : Array(String)
        return [] of String if @height <= 0 || @width <= 0 || @lines.empty?
        slice = @lines[@y_offset, Math.min(@height, @lines.size - @y_offset)]? || [] of String
        lines = slice.map do |line|
          if Ansi.string_width(line) <= @x_offset
            ""
          else
            Ansi.cut(line, @x_offset, @x_offset + @width)
          end
        end
        while @fill_height && lines.size < @height
          lines << ""
        end
        lines
      end

      private def max_y_offset : Int32
        Math.max(0, total_line_count - @height)
      end

      private def max_x_offset : Int32
        Math.max(0, @longest_line_width - @width)
      end

      private def clamp(v : Int32, lo : Int32, hi : Int32) : Int32
        return lo if v < lo
        return hi if v > hi
        v
      end

      private def clampf(v : Float64, lo : Float64, hi : Float64) : Float64
        return lo if v < lo
        return hi if v > hi
        v
      end
    end

    def self.new(*opts : Option) : Model
      Model.new(*opts)
    end
  end
end
