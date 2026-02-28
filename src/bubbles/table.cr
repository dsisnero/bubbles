require "ansi"
require "lipgloss"
require "bubbletea"
require "./help"
require "./key"
require "./viewport"

module Bubbles
  module Table
    alias Row = Array(String)

    struct Column
      property title : String
      property width : Int32

      def initialize(@title : String = "", @width : Int32 = 0)
      end
    end

    struct KeyMap
      property line_up : Bubbles::Key::Binding
      property line_down : Bubbles::Key::Binding
      property page_up : Bubbles::Key::Binding
      property page_down : Bubbles::Key::Binding
      property half_page_up : Bubbles::Key::Binding
      property half_page_down : Bubbles::Key::Binding
      property goto_top : Bubbles::Key::Binding
      property goto_bottom : Bubbles::Key::Binding

      def initialize(
        @line_up = Bubbles::Key::Binding.new,
        @line_down = Bubbles::Key::Binding.new,
        @page_up = Bubbles::Key::Binding.new,
        @page_down = Bubbles::Key::Binding.new,
        @half_page_up = Bubbles::Key::Binding.new,
        @half_page_down = Bubbles::Key::Binding.new,
        @goto_top = Bubbles::Key::Binding.new,
        @goto_bottom = Bubbles::Key::Binding.new,
      )
      end

      def short_help : Array(Bubbles::Key::Binding)
        [@line_up, @line_down]
      end

      def full_help : Array(Array(Bubbles::Key::Binding))
        [
          [@line_up, @line_down, @goto_top, @goto_bottom],
          [@page_up, @page_down, @half_page_up, @half_page_down],
        ]
      end
    end

    def self.default_key_map : KeyMap
      KeyMap.new(
        line_up: Bubbles::Key.new_binding(Bubbles::Key.with_keys("up", "k"), Bubbles::Key.with_help("↑/k", "up")),
        line_down: Bubbles::Key.new_binding(Bubbles::Key.with_keys("down", "j"), Bubbles::Key.with_help("↓/j", "down")),
        page_up: Bubbles::Key.new_binding(Bubbles::Key.with_keys("b", "pgup"), Bubbles::Key.with_help("b/pgup", "page up")),
        page_down: Bubbles::Key.new_binding(Bubbles::Key.with_keys("f", "pgdown", "space"), Bubbles::Key.with_help("f/pgdn", "page down")),
        half_page_up: Bubbles::Key.new_binding(Bubbles::Key.with_keys("u", "ctrl+u"), Bubbles::Key.with_help("u", "½ page up")),
        half_page_down: Bubbles::Key.new_binding(Bubbles::Key.with_keys("d", "ctrl+d"), Bubbles::Key.with_help("d", "½ page down")),
        goto_top: Bubbles::Key.new_binding(Bubbles::Key.with_keys("home", "g"), Bubbles::Key.with_help("g/home", "go to start")),
        goto_bottom: Bubbles::Key.new_binding(Bubbles::Key.with_keys("end", "G"), Bubbles::Key.with_help("G/end", "go to end"))
      )
    end

    struct Styles
      property header : Lipgloss::Style
      property cell : Lipgloss::Style
      property selected : Lipgloss::Style

      def initialize(
        @header = Lipgloss::Style.new,
        @cell = Lipgloss::Style.new,
        @selected = Lipgloss::Style.new,
      )
      end
    end

    def self.default_styles : Styles
      Styles.new(
        selected: Lipgloss.new_style.bold(true).foreground(Lipgloss.color("212")),
        header: Lipgloss.new_style.bold(true).padding(0, 1),
        cell: Lipgloss.new_style.padding(0, 1),
      )
    end

    alias Option = Proc(Model, Nil)

    def self.with_columns(cols : Array(Column)) : Option
      ->(m : Model) { m.cols = cols }
    end

    def self.with_rows(rows : Array(Row)) : Option
      ->(m : Model) { m.rows = rows }
    end

    def self.with_height(h : Int32) : Option
      ->(m : Model) { m.viewport.set_height(h - 1) }
    end

    def self.with_width(w : Int32) : Option
      ->(m : Model) { m.viewport.set_width(w) }
    end

    def self.with_focused(f : Bool) : Option
      ->(m : Model) { m.focus = f }
    end

    def self.with_styles(s : Styles) : Option
      ->(m : Model) { m.set_styles(s) }
    end

    def self.with_key_map(km : KeyMap) : Option
      ->(m : Model) { m.key_map = km }
    end

    class Model
      property key_map : KeyMap
      property help : Bubbles::Help::Model
      property cols : Array(Column)
      property rows : Array(Row)
      property cursor : Int32
      property focus : Bool # ameba:disable Naming/QueryBoolMethods
      property styles : Styles
      property viewport : Bubbles::Viewport::Model
      property start : Int32
      property end : Int32

      def initialize
        @key_map = Table.default_key_map
        @help = Bubbles::Help::Model.new
        @cols = [] of Column
        @rows = [] of Row
        @cursor = 0
        @focus = false
        @styles = Table.default_styles
        @viewport = Bubbles::Viewport.new(Bubbles::Viewport.with_height(20))
        @start = 0
        @end = 0
      end

      def self.new : Model
        m = allocate
        m.initialize
        m.update_viewport
        m
      end

      def self.new(*opts : Option) : Model
        m = allocate
        m.initialize
        opts.each(&.call(m))
        m.update_viewport
        m
      end

      def update(msg : Tea::Msg) : {Model, Tea::Cmd?}
        return {self, nil} unless @focus

        if kmsg = msg.as?(Tea::KeyPressMsg)
          case
          when Bubbles::Key.matches?(kmsg, @key_map.line_up)
            move_up(1)
          when Bubbles::Key.matches?(kmsg, @key_map.line_down)
            move_down(1)
          when Bubbles::Key.matches?(kmsg, @key_map.page_up)
            move_up(@viewport.height)
          when Bubbles::Key.matches?(kmsg, @key_map.page_down)
            move_down(@viewport.height)
          when Bubbles::Key.matches?(kmsg, @key_map.half_page_up)
            move_up(@viewport.height // 2)
          when Bubbles::Key.matches?(kmsg, @key_map.half_page_down)
            move_down(@viewport.height // 2)
          when Bubbles::Key.matches?(kmsg, @key_map.goto_top)
            goto_top
          when Bubbles::Key.matches?(kmsg, @key_map.goto_bottom)
            goto_bottom
          end
        end

        {self, nil}
      end

      def focused? : Bool
        @focus
      end

      def focus
        @focus = true
        update_viewport
      end

      def blur
        @focus = false
        update_viewport
      end

      def view : String
        headers_view + "\n" + @viewport.view
      end

      def help_view : String
        @help.view(@key_map)
      end

      def set_styles(s : Styles) # ameba:disable Naming/AccessorMethodName
        @styles = s
        update_viewport
      end

      def styles=(s : Styles)
        set_styles(s)
      end

      def selected_row : Row?
        return nil if @cursor < 0 || @cursor >= @rows.size
        @rows[@cursor]
      end

      def columns : Array(Column)
        @cols
      end

      def set_rows(r : Array(Row)) # ameba:disable Naming/AccessorMethodName
        @rows = r
        if @cursor > @rows.size - 1
          @cursor = @rows.size - 1
        end
        update_viewport
      end

      def rows=(r : Array(Row))
        set_rows(r)
      end

      def set_columns(c : Array(Column)) # ameba:disable Naming/AccessorMethodName
        @cols = c
        update_viewport
      end

      def columns=(c : Array(Column))
        set_columns(c)
      end

      def set_width(w : Int32) # ameba:disable Naming/AccessorMethodName
        @viewport.set_width(w)
        update_viewport
      end

      def width=(w : Int32)
        set_width(w)
      end

      def set_height(h : Int32) # ameba:disable Naming/AccessorMethodName
        @viewport.set_height(h - Lipgloss.height(headers_view))
        update_viewport
      end

      def height=(h : Int32)
        set_height(h)
      end

      def height : Int32
        @viewport.height
      end

      def width : Int32
        @viewport.width
      end

      def viewport_height : Int32
        @viewport.height
      end

      def viewport_width : Int32
        @viewport.width
      end

      def set_cursor(n : Int32) # ameba:disable Naming/AccessorMethodName
        @cursor = clamp(n, 0, @rows.size - 1)
        update_viewport
      end

      def cursor=(n : Int32)
        set_cursor(n)
      end

      def move_up(n : Int32)
        @cursor = clamp(@cursor - n, 0, @rows.size - 1)

        offset = @viewport.y_offset
        case
        when @start == 0
          offset = clamp(offset, 0, @cursor)
        when @start < @viewport.height
          offset = clamp(clamp(offset + n, 0, @cursor), 0, @viewport.height)
        when offset >= 1
          offset = clamp(offset + n, 1, @viewport.height)
        end
        @viewport.set_y_offset(offset)
        update_viewport
      end

      def move_down(n : Int32)
        @cursor = clamp(@cursor + n, 0, @rows.size - 1)
        update_viewport

        offset = @viewport.y_offset
        case
        when @end == @rows.size && offset > 0
          offset = clamp(offset - n, 1, @viewport.height)
        when @cursor > (@end - @start) // 2 && offset > 0
          offset = clamp(offset - n, 1, @cursor)
        when offset > 1
          # no-op parity branch
        when @cursor > offset + @viewport.height - 1
          offset = clamp(offset + 1, 0, 1)
        end
        @viewport.set_y_offset(offset)
      end

      def goto_top
        move_up(@cursor)
      end

      def goto_bottom
        move_down(@rows.size)
      end

      def from_values(value : String, separator : String)
        new_rows = [] of Row
        value.split("\n").each do |line|
          r = [] of String
          line.split(separator).each { |field| r << field }
          new_rows << r
        end
        set_rows(new_rows)
      end

      def update_viewport
        rendered_rows = [] of String

        if @cursor >= 0
          @start = clamp(@cursor - @viewport.height, 0, @cursor)
        else
          @start = 0
        end
        @end = clamp(@cursor + @viewport.height, @cursor, @rows.size)

        i = @start
        while i < @end
          rendered_rows << render_row(i)
          i += 1
        end

        @viewport.set_content(Lipgloss.join_vertical(Lipgloss::Position::Left, rendered_rows))
      end

      def render_row(r : Int32) : String
        cells = [] of String
        row = @rows[r]? || [] of String

        row.each_with_index do |value, i|
          next if i >= @cols.size
          next if @cols[i].width <= 0

          style = Lipgloss.new_style.width(@cols[i].width).max_width(@cols[i].width).inline(true)
          rendered_cell = @styles.cell.render(style.render(Ansi.truncate(value, @cols[i].width, "…")))
          cells << rendered_cell
        end

        rendered_row = Lipgloss.join_horizontal(Lipgloss::Position::Top, cells)
        if r == @cursor
          @styles.selected.render(rendered_row)
        else
          rendered_row
        end
      end

      private def headers_view : String
        cells = [] of String
        @cols.each do |col|
          next if col.width <= 0
          style = Lipgloss.new_style.width(col.width).max_width(col.width).inline(true)
          rendered_cell = style.render(Ansi.truncate(col.title, col.width, "…"))
          cells << @styles.header.render(rendered_cell)
        end
        Lipgloss.join_horizontal(Lipgloss::Position::Top, cells)
      end

      private def clamp(v : Int32, low : Int32, high : Int32) : Int32
        min(max(v, low), high)
      end

      private def max(a : Int32, b : Int32) : Int32
        a > b ? a : b
      end

      private def min(a : Int32, b : Int32) : Int32
        a < b ? a : b
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
