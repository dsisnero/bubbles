require "bubbletea"
require "./key"
require "ansi"
require "lipgloss"
require "./viewport/highlight"

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
      property style : Lipgloss::Style
      property left_gutter_func : GutterFunc
      property highlight_style : Lipgloss::Style
      property selected_highlight_style : Lipgloss::Style
      property style_line_func : (Int32 -> Lipgloss::Style)?

      @width : Int32
      @height : Int32
      @y_offset : Int32
      @x_offset : Int32
      @horizontal_step : Int32
      @lines : Array(String)
      @longest_line_width : Int32
      @highlights : Array(HighlightInfo)
      @hi_idx : Int32
      @initialized : Bool

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
        @style = Lipgloss::Style.new
        @left_gutter_func = NoGutter
        @lines = [] of String
        @longest_line_width = 0
        @highlights = [] of HighlightInfo
        @hi_idx = -1
        @highlight_style = Lipgloss::Style.new
        @selected_highlight_style = Lipgloss::Style.new
        @style_line_func = nil
        @initialized = false
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
        return if matches.empty? || @lines.empty?
        @highlights = Viewport.parse_matches(get_content, matches)
        @hi_idx = find_nearest_match
        show_highlight
      end

      def highlights=(matches : Array(Array(Int32)))
        set_highlights(matches)
      end

      def clear_highlights
        @highlights.clear
        @hi_idx = -1
      end

      def highlight_next
        return if @highlights.empty?
        @hi_idx = (@hi_idx + 1) % @highlights.size
        show_highlight
      end

      def highlight_previous
        return if @highlights.empty?
        @hi_idx = (@hi_idx - 1) % @highlights.size
        show_highlight
      end

      private def show_highlight
        return if @hi_idx == -1
        line, colstart, colend = @highlights[@hi_idx].coords
        ensure_visible(line, colstart, colend)
      end

      private def find_nearest_match : Int32
        @highlights.each_with_index do |match, i|
          return i if match.line_start >= @y_offset
        end
        -1
      end

      def ensure_visible(line : Int32, colstart : Int32, colend : Int32)
        max_width = max_width()
        if colend <= max_width
          @x_offset = 0
        else
          @x_offset = colstart - @horizontal_step # put one step to the left, feels more natural
        end

        if line < @y_offset || line >= @y_offset + max_height()
          @y_offset = line
        end
        set_y_offset(@y_offset)
      end

      private def style_lines(lines : Array(String), offset : Int32) : Array(String)
        func = @style_line_func
        return lines unless func
        lines.map_with_index do |line, i|
          style = func.call(i + offset)
          style.render(line)
        end
      end

      private def highlight_lines(lines : Array(String), offset : Int32) : Array(String)
        return lines if @highlights.empty?
        lines.map_with_index do |line, i|
          ranges = Viewport.make_highlight_ranges(@highlights, i + offset, @highlight_style)
          line = Lipgloss.style_ranges(line, ranges)
          if @hi_idx >= 0
            sel = @highlights[@hi_idx]
            if hl = sel.lines[i + offset]?
              line = Lipgloss.style_ranges(line, [Lipgloss.new_range(hl[0], hl[1], @selected_highlight_style)])
            end
          end
          line
        end
      end

      def view : String
        return "" if @width <= 0 || @height <= 0
        content = visible_lines.join("\n")
        Lipgloss.new_style.width(@width).height(@height).render(content)
      end

      private def visible_lines : Array(String)
        max_height = max_height()
        max_width = max_width()

        if max_height == 0 || max_width == 0
          return [] of String
        end

        total, ridx, voffset = calculate_line(@y_offset)
        lines = [] of String
        if total > 0
          bottom = clamp(ridx + max_height, ridx, @lines.size)
          lines = @lines[ridx...bottom].dup
          lines = style_lines(lines, ridx)
          lines = highlight_lines(lines, ridx)
        end

        while @fill_height && lines.size < max_height
          lines << ""
        end

        # if longest line fit within width, no need to do anything else.
        if (@x_offset == 0 && @longest_line_width <= max_width) || max_width == 0
          return setup_gutter(lines, total, ridx)
        end

        if @soft_wrap
          return soft_wrap(lines, max_width, max_height, total, ridx, voffset)
        end

        # Cut the lines to the viewport width.
        lines.map! do |line|
          Ansi.cut(line, @x_offset, @x_offset + max_width)
        end
        setup_gutter(lines, total, ridx)
      end

      # setup_gutter sets up the left gutter using Model#left_gutter_func.
      private def setup_gutter(lines : Array(String), total : Int32, ridx : Int32) : Array(String)
        return lines unless @left_gutter_func
        lines.map_with_index do |line, i|
          @left_gutter_func.call(GutterContext.new(
            index: i + ridx,
            total_lines: total,
            soft: false
          )) + line
        end
      end

      private def soft_wrap(lines : Array(String), max_width : Int32, max_height : Int32,
                            total : Int32, ridx : Int32, voffset : Int32) : Array(String)
        # TODO: Implement soft wrap
        lines.map! do |line|
          Ansi.cut(line, @x_offset, @x_offset + max_width)
        end
        setup_gutter(lines, total, ridx)
      end

      private def max_width : Int32
        gutter_size = 0
        if @left_gutter_func
          gutter_size = Ansi.string_width(@left_gutter_func.call(GutterContext.new))
        end
        Math.max(0, @width - @style.get_horizontal_frame_size - gutter_size)
      end

      private def max_height : Int32
        Math.max(0, @height - @style.get_vertical_frame_size)
      end

      # calculate_line taking soft wrapping into account, returns the total viewable
      # lines and the real-line index for the given yoffset, as well as the virtual
      # line offset.
      private def calculate_line(yoffset : Int32) : Tuple(Int32, Int32, Int32)
        unless @soft_wrap
          total = @lines.size
          ridx = Math.min(yoffset, @lines.size)
          return {total, ridx, 0}
        end

        max_width = max_width().to_f
        total = 0
        ridx = 0
        voffset = 0

        @lines.each_with_index do |line, i|
          line_height = Math.max(1, (Ansi.string_width(line).to_f / max_width).ceil.to_i)

          if yoffset >= total && yoffset < total + line_height
            ridx = i
            voffset = yoffset - total
          end
          total += line_height
        end

        if yoffset >= total
          ridx = @lines.size
          voffset = 0
        end

        {total, ridx, voffset}
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

      # Update handles messages and updates the viewport.
      # Ported from Go: vendor/bubbles/viewport/viewport.go:656
      def update(msg : Tea::Msg) : {Model, Tea::Cmd?}
        # Basic implementation - just return self for now
        {self, nil}
      end
    end

    def self.new(*opts : Option) : Model
      Model.new(*opts)
    end
  end
end
