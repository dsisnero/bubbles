require "digest/sha256"
require "./cursor"
require "./key"
require "./viewport"
require "./internal/memoization"
require "./internal/runeutil"

module Bubbles
  module Textarea
    # Constants ported from Go: vendor/bubbles/textarea/textarea.go:32-38
    MIN_HEIGHT         =     1
    DEFAULT_HEIGHT     =     6
    DEFAULT_WIDTH      =    40
    DEFAULT_CHAR_LIMIT =     0 # no limit
    DEFAULT_MAX_HEIGHT =    99
    DEFAULT_MAX_WIDTH  =   500
    MAX_LINES          = 10000 # maximum number of lines in the textarea

    # pasteMsg is a message containing pasted content.
    # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:42
    class PasteMsg
      include Tea::Msg
      property chars : Array(Char)

      def initialize(@chars : Array(Char)); end
    end

    # pasteErrMsg is a message containing a paste error.
    # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:43
    class PasteErrMsg
      include Tea::Msg
      property error : Exception

      def initialize(@error : Exception); end
    end

    # maxHeightHitMsg is an internal message indicating MaxHeight constraint was hit.
    # Used to signal Update to return immediately (Go parity).
    private class MaxHeightHitMsg
      include Tea::Msg
    end

    # KeyMap is the key bindings for different actions within the textarea.
    # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:47
    struct KeyMap
      property character_backward : Key::Binding
      property character_forward : Key::Binding
      property delete_after_cursor : Key::Binding
      property delete_before_cursor : Key::Binding
      property delete_character_backward : Key::Binding
      property delete_character_forward : Key::Binding
      property delete_word_backward : Key::Binding
      property delete_word_forward : Key::Binding
      property insert_newline : Key::Binding
      property line_end : Key::Binding
      property line_next : Key::Binding
      property line_previous : Key::Binding
      property line_start : Key::Binding
      property page_up : Key::Binding
      property page_down : Key::Binding
      property paste : Key::Binding
      property word_backward : Key::Binding
      property word_forward : Key::Binding
      property input_begin : Key::Binding
      property input_end : Key::Binding
      property uppercase_word_forward : Key::Binding
      property lowercase_word_forward : Key::Binding
      property capitalize_word_forward : Key::Binding
      property transpose_character_backward : Key::Binding

      def initialize(
        @character_backward : Key::Binding,
        @character_forward : Key::Binding,
        @delete_after_cursor : Key::Binding,
        @delete_before_cursor : Key::Binding,
        @delete_character_backward : Key::Binding,
        @delete_character_forward : Key::Binding,
        @delete_word_backward : Key::Binding,
        @delete_word_forward : Key::Binding,
        @insert_newline : Key::Binding,
        @line_end : Key::Binding,
        @line_next : Key::Binding,
        @line_previous : Key::Binding,
        @line_start : Key::Binding,
        @page_up : Key::Binding,
        @page_down : Key::Binding,
        @paste : Key::Binding,
        @word_backward : Key::Binding,
        @word_forward : Key::Binding,
        @input_begin : Key::Binding,
        @input_end : Key::Binding,
        @uppercase_word_forward : Key::Binding,
        @lowercase_word_forward : Key::Binding,
        @capitalize_word_forward : Key::Binding,
        @transpose_character_backward : Key::Binding,
      )
      end
    end

    # DefaultKeyMap returns the default set of key bindings for navigating and acting
    # upon the textarea.
    # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:78
    def self.default_key_map : KeyMap
      KeyMap.new(
        character_forward: Key.new_binding(Key.with_keys("right", "ctrl+f"), Key.with_help("right", "character forward")),
        character_backward: Key.new_binding(Key.with_keys("left", "ctrl+b"), Key.with_help("left", "character backward")),
        word_forward: Key.new_binding(Key.with_keys("alt+right", "alt+f"), Key.with_help("alt+right", "word forward")),
        word_backward: Key.new_binding(Key.with_keys("alt+left", "alt+b"), Key.with_help("alt+left", "word backward")),
        line_next: Key.new_binding(Key.with_keys("down", "ctrl+n"), Key.with_help("down", "next line")),
        line_previous: Key.new_binding(Key.with_keys("up", "ctrl+p"), Key.with_help("up", "previous line")),
        delete_word_backward: Key.new_binding(Key.with_keys("alt+backspace", "ctrl+w"), Key.with_help("alt+backspace", "delete word backward")),
        delete_word_forward: Key.new_binding(Key.with_keys("alt+delete", "alt+d"), Key.with_help("alt+delete", "delete word forward")),
        delete_after_cursor: Key.new_binding(Key.with_keys("ctrl+k"), Key.with_help("ctrl+k", "delete after cursor")),
        delete_before_cursor: Key.new_binding(Key.with_keys("ctrl+u"), Key.with_help("ctrl+u", "delete before cursor")),
        insert_newline: Key.new_binding(Key.with_keys("enter", "ctrl+m"), Key.with_help("enter", "insert newline")),
        delete_character_backward: Key.new_binding(Key.with_keys("backspace", "ctrl+h"), Key.with_help("backspace", "delete character backward")),
        delete_character_forward: Key.new_binding(Key.with_keys("delete", "ctrl+d"), Key.with_help("delete", "delete character forward")),
        line_start: Key.new_binding(Key.with_keys("home", "ctrl+a"), Key.with_help("home", "line start")),
        line_end: Key.new_binding(Key.with_keys("end", "ctrl+e"), Key.with_help("end", "line end")),
        page_up: Key.new_binding(Key.with_keys("pgup"), Key.with_help("pgup", "page up")),
        page_down: Key.new_binding(Key.with_keys("pgdown"), Key.with_help("pgdown", "page down")),
        paste: Key.new_binding(Key.with_keys("ctrl+v"), Key.with_help("ctrl+v", "paste")),
        input_begin: Key.new_binding(Key.with_keys("alt+<", "ctrl+home"), Key.with_help("alt+<", "input begin")),
        input_end: Key.new_binding(Key.with_keys("alt+>", "ctrl+end"), Key.with_help("alt+>", "input end")),
        capitalize_word_forward: Key.new_binding(Key.with_keys("alt+c"), Key.with_help("alt+c", "capitalize word forward")),
        lowercase_word_forward: Key.new_binding(Key.with_keys("alt+l"), Key.with_help("alt+l", "lowercase word forward")),
        uppercase_word_forward: Key.new_binding(Key.with_keys("alt+u"), Key.with_help("alt+u", "uppercase word forward")),
        transpose_character_backward: Key.new_binding(Key.with_keys("ctrl+t"), Key.with_help("ctrl+t", "transpose character backward"))
      )
    end

    struct LineInfo
      property width : Int32
      property char_width : Int32
      property height : Int32
      property start_column : Int32
      property column_offset : Int32
      property row_offset : Int32
      property char_offset : Int32

      def initialize(
        @width : Int32 = 0,
        @char_width : Int32 = 0,
        @height : Int32 = 1,
        @start_column : Int32 = 0,
        @column_offset : Int32 = 0,
        @row_offset : Int32 = 0,
        @char_offset : Int32 = 0,
      )
      end
    end

    struct PromptInfo
      property line_number : Int32
      property focused : Bool # ameba:disable Naming/QueryBoolMethods

      def initialize(@line_number : Int32 = 0, @focused : Bool = false)
      end
    end

    # line is the input to the text wrapping function. This is stored in a struct
    # so that it can be hashed and memoized.
    # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:235
    struct Line
      include Internal::Memoization::Hasher

      property runes : Array(Char)
      property width : Int32

      def initialize(@runes : Array(Char), @width : Int32)
      end

      # Hash returns a hash of the line.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:241
      def hash : String
        Digest::SHA256.hexdigest("#{runes.join}:#{@width}")
      end

      # memo_hash returns a hash for memoization.
      def memo_hash : String
        hash
      end
    end

    # CursorStyle is the style for real and virtual cursors.
    # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:148
    struct CursorStyle
      property color : String? # TODO: Use proper color type
      property shape : String  # TODO: Use proper CursorShape enum
      property blink : Bool    # ameba:disable Naming/QueryBoolMethods
      property blink_speed : Time::Span

      def initialize(@color = nil, @shape = "block", @blink = false, @blink_speed = 500.milliseconds)
      end
    end

    # Styles are the styles for the textarea, separated into focused and blurred
    # states. The appropriate styles will be chosen based on the focus state of
    # the textarea.
    # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:178
    struct Styles
      property focused : StyleState
      property blurred : StyleState
      property cursor : CursorStyle

      def initialize(@focused : StyleState, @blurred : StyleState, @cursor : CursorStyle)
      end
    end

    # StyleState that will be applied to the text area.
    # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:191
    struct StyleState
      property base : Lipgloss::Style
      property text : Lipgloss::Style
      property line_number : Lipgloss::Style
      property cursor_line_number : Lipgloss::Style
      property cursor_line : Lipgloss::Style
      property end_of_buffer : Lipgloss::Style
      property placeholder : Lipgloss::Style
      property prompt : Lipgloss::Style

      def initialize(
        @base : Lipgloss::Style = Lipgloss::Style.new,
        @text : Lipgloss::Style = Lipgloss::Style.new,
        @line_number : Lipgloss::Style = Lipgloss::Style.new,
        @cursor_line_number : Lipgloss::Style = Lipgloss::Style.new,
        @cursor_line : Lipgloss::Style = Lipgloss::Style.new,
        @end_of_buffer : Lipgloss::Style = Lipgloss::Style.new,
        @placeholder : Lipgloss::Style = Lipgloss::Style.new,
        @prompt : Lipgloss::Style = Lipgloss::Style.new,
      )
      end

      # computedCursorLine returns the computed style for the cursor line.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:202
      def computed_cursor_line : Lipgloss::Style
        @cursor_line.inherit(@base).inline(true)
      end

      # computedCursorLineNumber returns the computed style for the cursor line number.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:206
      def computed_cursor_line_number : Lipgloss::Style
        @cursor_line_number
          .inherit(@cursor_line)
          .inherit(@base)
          .inline(true)
      end

      # computedEndOfBuffer returns the computed style for the end of buffer character.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:213
      def computed_end_of_buffer : Lipgloss::Style
        @end_of_buffer.inherit(@base).inline(true)
      end

      # computedLineNumber returns the computed style for line numbers.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:217
      def computed_line_number : Lipgloss::Style
        @line_number.inherit(@base).inline(true)
      end

      # computedPlaceholder returns the computed style for the placeholder.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:221
      def computed_placeholder : Lipgloss::Style
        @placeholder.inherit(@base).inline(true)
      end

      # computedPrompt returns the computed style for the prompt.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:225
      def computed_prompt : Lipgloss::Style
        @prompt.inherit(@base).inline(true)
      end

      # computedText returns the computed style for text.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:229
      def computed_text : Lipgloss::Style
        @text.inherit(@base).inline(true)
      end
    end

    # DefaultStyles returns the default styles for focused and blurred states for
    # the textarea.
    # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:375
    def self.default_styles(is_dark : Bool = false) : Styles
      ld = ->(light : String, dark : String) { Lipgloss.color(is_dark ? dark : light) }

      focused = StyleState.new(
        base: Lipgloss::Style.new,
        cursor_line: Lipgloss::Style.new.background(ld.call("255", "0")),
        cursor_line_number: Lipgloss::Style.new.foreground(ld.call("240", "240")),
        end_of_buffer: Lipgloss::Style.new.foreground(ld.call("254", "0")),
        line_number: Lipgloss::Style.new.foreground(ld.call("249", "7")),
        placeholder: Lipgloss::Style.new.foreground(Lipgloss.color("240")),
        prompt: Lipgloss::Style.new.foreground(Lipgloss.color("7")),
        text: Lipgloss::Style.new
      )

      blurred = StyleState.new(
        base: Lipgloss::Style.new,
        cursor_line: Lipgloss::Style.new.foreground(ld.call("245", "7")),
        cursor_line_number: Lipgloss::Style.new.foreground(ld.call("249", "7")),
        end_of_buffer: Lipgloss::Style.new.foreground(ld.call("254", "0")),
        line_number: Lipgloss::Style.new.foreground(ld.call("249", "7")),
        placeholder: Lipgloss::Style.new.foreground(Lipgloss.color("240")),
        prompt: Lipgloss::Style.new.foreground(Lipgloss.color("7")),
        text: Lipgloss::Style.new.foreground(ld.call("245", "7"))
      )

      cursor = CursorStyle.new(
        color: "7",
        shape: "block",
        blink: true
      )
      Styles.new(focused, blurred, cursor)
    end

    # DefaultLightStyles returns the default styles for a light background.
    # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:410
    def self.default_light_styles : Styles
      default_styles(false)
    end

    # DefaultDarkStyles returns the default styles for a dark background.
    # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:415
    def self.default_dark_styles : Styles
      default_styles(true)
    end

    class Model
      property err : Exception?
      property prompt : String
      property placeholder : String
      property char_limit : Int32
      property width : Int32
      property height : Int32
      property row : Int32
      property col : Int32
      property dynamic_height : Bool
      property min_height : Int32
      property max_content_height : Int32
      property max_height : Int32
      property max_width : Int32
      property viewport : Bubbles::Viewport::Model

      @value : Array(Array(Char))
      @scroll_y_offset : Int32
      @prompt_func : (PromptInfo -> String)?
      @prompt_width : Int32
      @styles : Styles
      @end_of_buffer_character : Char
      @max_height : Int32
      @max_width : Int32
      @dynamic_height : Bool
      @min_height : Int32
      @max_content_height : Int32
      @focus : Bool
      @rsan : Internal::Runeutil::Sanitizer?
      @cache : Internal::Memoization::MemoCache(Line, Array(Array(Char)))
      @show_line_numbers : Bool
      @key_map : KeyMap
      @use_virtual_cursor : Bool
      @virtual_cursor : Cursor::Model
      @last_char_offset : Int32
      @viewport : Bubbles::Viewport::Model

      def initialize
        @err = nil
        @prompt = "#{Lipgloss.thick_border.left} "
        @placeholder = ""
        @char_limit = DEFAULT_CHAR_LIMIT
        @max_height = DEFAULT_MAX_HEIGHT
        @max_width = DEFAULT_MAX_WIDTH
        @dynamic_height = false
        @min_height = 1
        @max_content_height = 0
        @width = DEFAULT_WIDTH
        @height = DEFAULT_HEIGHT
        @row = 0
        @col = 0
        @value = Array(Array(Char)).new(MIN_HEIGHT) { [] of Char }
        @scroll_y_offset = 0
        @prompt_func = nil
        @prompt_width = 0
        @styles = Textarea.default_dark_styles
        @end_of_buffer_character = ' '
        @focus = false
        @rsan = nil
        @cache = Internal::Memoization::MemoCache(Line, Array(Array(Char))).new(MAX_LINES)
        @show_line_numbers = true
        @key_map = Textarea.default_key_map
        @use_virtual_cursor = true
        @virtual_cursor = Cursor::Model.new
        @last_char_offset = 0
        @viewport = Bubbles::Viewport::Model.new

        set_height(DEFAULT_HEIGHT)
        set_width(DEFAULT_WIDTH)
        update_virtual_cursor_style
      end

      def self.new : Model
        m = allocate
        m.initialize
        m
      end

      # Focused returns the focus state on the model.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:709
      def focused : Bool
        @focus
      end

      # activeStyle returns the appropriate set of styles to use depending on
      # whether the textarea is focused or blurred.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:715
      private def active_style : StyleState
        if @focus
          @styles.focused
        else
          @styles.blurred
        end
      end

      # Focus sets the focus state on the model. When the model is in focus it can
      # receive keyboard input and the cursor will be hidden.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:724
      def focus : Tea::Cmd?
        @focus = true
        @virtual_cursor.focus
      end

      # Blur removes the focus state on the model. When the model is blurred it can
      # not receive keyboard input and the cursor will be hidden.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:731
      def blur
        @focus = false
        @virtual_cursor.blur
      end

      # init initializes the model.
      def init : Tea::Cmd?
        nil
      end

      # styles returns the current styles for the textarea.
      def styles : Styles
        @styles
      end

      # setStyles updates styling for the textarea.
      def set_styles(s : Styles) # ameba:disable Naming/AccessorMethodName
        @styles = s
        update_virtual_cursor_style
      end

      def styles=(s : Styles)
        set_styles(s)
      end

      # keyMap returns the current key bindings.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go (KeyMap field access).
      def key_map : KeyMap
        @key_map
      end

      # setKeyMap updates key bindings.
      def set_key_map(km : KeyMap) # ameba:disable Naming/AccessorMethodName
        @key_map = km
      end

      def key_map=(km : KeyMap)
        set_key_map(km)
      end

      # showLineNumbers controls whether line numbers are rendered.
      def show_line_numbers : Bool
        @show_line_numbers
      end

      def show_line_numbers? : Bool
        @show_line_numbers
      end

      def set_show_line_numbers(v : Bool) # ameba:disable Naming/AccessorMethodName
        @show_line_numbers = v
      end

      def show_line_numbers=(v : Bool)
        set_show_line_numbers(v)
      end

      # virtualCursor returns whether or not the virtual cursor is enabled.
      def virtual_cursor : Bool
        @use_virtual_cursor
      end

      def virtual_cursor? : Bool
        @use_virtual_cursor
      end

      # setVirtualCursor sets whether or not to use the virtual cursor.
      def set_virtual_cursor(v : Bool) # ameba:disable Naming/AccessorMethodName
        @use_virtual_cursor = v
        update_virtual_cursor_style
      end

      def virtual_cursor=(v : Bool)
        set_virtual_cursor(v)
      end

      private def update_virtual_cursor_style
        unless @use_virtual_cursor
          @virtual_cursor.set_mode(Cursor::Mode::Hide)
          return
        end

        if color = @styles.cursor.color
          @virtual_cursor.style = Lipgloss::Style.new.foreground(color)
        else
          @virtual_cursor.style = Lipgloss::Style.new
        end

        if @styles.cursor.blink
          if @styles.cursor.blink_speed > 0.seconds
            @virtual_cursor.blink_speed = @styles.cursor.blink_speed
          end
          @virtual_cursor.set_mode(Cursor::Mode::Blink)
        else
          @virtual_cursor.set_mode(Cursor::Mode::Static)
        end
      end

      # reset sets the input to its default state with no input.
      def reset
        @value = Array(Array(Char)).new(MIN_HEIGHT) { [] of Char }
        @col = 0
        @row = 0
        @viewport.goto_top
        set_cursor_column(0)
        recalculate_height
      end

      # san returns the rune sanitizer for the model.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:781
      private def san : Internal::Runeutil::Sanitizer
        if @rsan.nil?
          # Textinput has all its input on a single line so collapse
          # newlines/tabs to single spaces.
          @rsan = Internal::Runeutil::DefaultSanitizer.new(Internal::Runeutil::SanitizerConfig.new)
        end
        @rsan.as(Internal::Runeutil::Sanitizer)
      end

      def set_value(s : String) # ameba:disable Naming/AccessorMethodName
        reset
        insert_string(s)
        recalculate_height
      end

      def value=(s : String)
        set_value(s)
      end

      def value : String
        @value.map(&.join).join("\n")
      end

      def insert_string(s : String)
        s.each_char { |char| insert_rune(char) }
        recalculate_height
      end

      def insert_rune(r : Char)
        return if @char_limit > 0 && length >= @char_limit

        if r == '\n'
          current = @value[@row]
          left = current[0, @col]
          right = current[@col..] || [] of Char
          @value[@row] = left
          @value.insert(@row + 1, right)
          @row += 1
          @col = 0
          return
        end

        line = @value[@row]
        line.insert(@col, r)
        @col += 1
      end

      # insert_runes_from_user_input inserts runes from user input (e.g., pasting or typing).
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:480
      private def insert_runes_from_user_input(runes : Array(Char))
        # Clean up any special characters in the input provided by the
        # clipboard. This avoids bugs due to e.g. tab characters and
        # whatnot.
        runes = san.sanitize(runes)

        if @char_limit > 0
          avail_space = @char_limit - length
          # If the char limit's been reached, cancel.
          return if avail_space <= 0
          # If there's not enough space to paste the whole thing cut the pasted
          # runes down so they'll fit.
          if avail_space < runes.size
            runes = runes[0, avail_space]
          end
        end

        # Split the input into lines.
        lines = [] of Array(Char)
        lstart = 0
        runes.each_with_index do |run, i|
          if run == '\n'
            # Queue a line to become a new row in the text area below.
            # Beware to clamp the max capacity of the slice, to ensure no
            # data from different rows get overwritten when later edits
            # will modify this line.
            lines << runes[lstart...i]
            lstart = i + 1
          end
        end
        if lstart <= runes.size
          # The last line did not end with a newline character.
          # Take it now.
          lines << runes[lstart..]
        end

        # Obey the maximum line limit.
        if MAX_LINES > 0 && @value.size + lines.size - 1 > MAX_LINES
          allowed_height = Math.max(0, MAX_LINES - @value.size + 1)
          lines = lines[0, allowed_height]
        end

        # Obey MaxContentHeight in visual rows when set.
        if @max_content_height > 0
          budget = @max_content_height - total_visual_lines
          while lines.size > 1 && visual_lines_for_insert(lines) > budget
            lines = lines[0, lines.size - 1]
          end
          if visual_lines_for_insert(lines) > budget
            return
          end
        end

        return if lines.empty?

        # Save the remainder of the original line at the current
        # cursor position.
        tail = @value[@row][@col..]? || [] of Char

        # Paste the first line at the current cursor position.
        @value[@row] = @value[@row][0...@col] + lines[0]
        @col += lines[0].size

        if (num_extra_lines = lines.size - 1) > 0
          # Add the new lines.
          # Crystal arrays don't expose capacity, so build the expanded grid.
          new_grid = Array(Array(Char)).new(@value.size + num_extra_lines) { [] of Char }
          new_grid[0..@row] = @value[0..@row]
          # Add all the rows that were after the cursor in the original
          # grid at the end of the new grid.
          (@row + 1...@value.size).each_with_index do |src_idx, dst_idx|
            new_grid[@row + 1 + num_extra_lines + dst_idx] = @value[src_idx]
          end
          @value = new_grid
          # Insert all the new lines in the middle.
          lines[1..].each do |line|
            @row += 1
            @value[@row] = line
            @col = line.size
          end
        end

        # Append the tail to the last line.
        @value[@row] = @value[@row] + tail
      end

      def length : Int32
        total = 0
        @value.each do |row|
          total += UnicodeCharWidth.width(row.join)
        end
        total + @value.size - 1
      end

      def line_count : Int32
        @value.size
      end

      def line : Int32
        @row
      end

      def column : Int32
        @col
      end

      def scroll_y_offset : Int32
        @scroll_y_offset
      end

      def cursor_up
        set_cursor_line_relative(-1)
      end

      def cursor_down
        set_cursor_line_relative(1)
      end

      def set_cursor_column(c : Int32) # ameba:disable Naming/AccessorMethodName
        @col = clamp(c, 0, @value[@row].size)
        @last_char_offset = 0
      end

      def cursor_column=(c : Int32)
        set_cursor_column(c)
      end

      # cursorStart moves the cursor to the start of the input field.
      def cursor_start
        set_cursor_column(0)
      end

      # cursorEnd moves the cursor to the end of the input field.
      def cursor_end
        set_cursor_column(@value[@row].size)
      end

      # setCursorLineRelative moves the cursor by the given number of lines.
      # Negative values move the cursor up, positive values move the cursor down.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:620
      private def set_cursor_line_relative(delta : Int32)
        return if delta == 0

        li = line_info
        char_offset = Math.max(@last_char_offset, li.char_offset)
        @last_char_offset = char_offset

        # 2 columns to account for trailing space wrapping.
        trailing_space = 2

        if delta > 0
          delta.times do
            if li.row_offset + 1 >= li.height && @row < @value.size - 1
              @row += 1
              @col = 0
            else
              @col = Math.min(li.start_column + li.width + trailing_space, @value[@row].size - 1)
            end
            li = line_info
          end
        else
          (-delta).times do
            if li.row_offset <= 0 && @row > 0
              @row -= 1
              @col = @value[@row].size
            else
              @col = li.start_column - trailing_space
            end
            li = line_info
          end
        end

        nli = line_info
        @col = nli.start_column

        if nli.width <= 0
          reposition_view
          return
        end

        offset = 0
        while offset < char_offset
          break if @row >= @value.size || @col >= @value[@row].size || offset >= nli.char_width - 1

          offset += UnicodeCharWidth.width(@value[@row][@col].to_s)
          @col += 1
        end

        reposition_view
      end

      def move_to_begin
        @row = 0
        set_cursor_column(0)
        reposition_view
      end

      # MoveToEnd moves the cursor to the end of the textarea.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1066
      def move_to_end
        @row = @value.size - 1
        set_cursor_column(@value[@row].size)
        reposition_view
      end

      def word : String
        line_chars = @value[@row]
        return "" if line_chars.empty?
        start_idx = @col - 1
        start_idx = 0 if start_idx < 0
        while start_idx > 0 && !line_chars[start_idx - 1].whitespace?
          start_idx -= 1
        end
        end_idx = @col
        while end_idx < line_chars.size && !line_chars[end_idx].whitespace?
          end_idx += 1
        end
        line_chars[start_idx...end_idx].join
      end

      # deleteBeforeCursor deletes all text before the cursor.
      private def delete_before_cursor
        @value[@row] = @value[@row][@col..]
        set_cursor_column(0)
      end

      # deleteAfterCursor deletes all text after the cursor.
      private def delete_after_cursor
        @value[@row] = @value[@row][0...@col]
        set_cursor_column(@value[@row].size)
      end

      # transposeLeft exchanges the runes at the cursor and immediately before.
      private def transpose_left
        return if @col == 0 || @value[@row].size < 2
        set_cursor_column(@col - 1) if @col >= @value[@row].size
        @value[@row][@col - 1], @value[@row][@col] = @value[@row][@col], @value[@row][@col - 1]
        set_cursor_column(@col + 1) if @col < @value[@row].size
      end

      # deleteWordLeft deletes the word left to the cursor.
      private def delete_word_left
        return if @col == 0 || @value[@row].empty?

        old_col = @col

        set_cursor_column(@col - 1)
        while @value[@row][@col].whitespace?
          break if @col <= 0
          set_cursor_column(@col - 1)
        end

        while @col > 0
          if !@value[@row][@col].whitespace?
            set_cursor_column(@col - 1)
          else
            set_cursor_column(@col + 1) if @col > 0
            break
          end
        end

        if old_col > @value[@row].size
          @value[@row] = @value[@row][0...@col]
        else
          @value[@row] = @value[@row][0...@col] + @value[@row][old_col..]
        end
      end

      # deleteWordRight deletes the word right to the cursor.
      private def delete_word_right
        return if @col >= @value[@row].size || @value[@row].empty?

        old_col = @col

        while @col < @value[@row].size && @value[@row][@col].whitespace?
          set_cursor_column(@col + 1)
        end

        while @col < @value[@row].size
          if !@value[@row][@col].whitespace?
            set_cursor_column(@col + 1)
          else
            break
          end
        end

        if @col > @value[@row].size
          @value[@row] = @value[@row][0...old_col]
        else
          @value[@row] = @value[@row][0...old_col] + @value[@row][@col..]
        end

        set_cursor_column(old_col)
      end

      # LineInfo returns the number of characters from the start of the
      # (soft-wrapped) line and the (soft-wrapped) line width.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:992
      def line_info : LineInfo
        grid = memoized_wrap(@value[@row], @width)

        # Find out which line we are currently on. This can be determined by the
        # cursor column and counting the number of runes we need to skip.
        counter = 0
        grid.each_with_index do |line, i|
          # We wrap around to the next line if we're at the end of the previous
          # line so that we can be at the very beginning of the next row.
          if counter + line.size == @col && i + 1 < grid.size
            return LineInfo.new(
              char_offset: 0,
              column_offset: 0,
              height: grid.size,
              row_offset: i + 1,
              start_column: @col,
              width: grid[i + 1].size,
              char_width: UnicodeCharWidth.width(line.join)
            )
          end

          if counter + line.size >= @col
            take = Math.max(0, @col - counter)
            return LineInfo.new(
              char_offset: UnicodeCharWidth.width(line[0, take].join),
              column_offset: @col - counter,
              height: grid.size,
              row_offset: i,
              start_column: counter,
              width: line.size,
              char_width: UnicodeCharWidth.width(line.join)
            )
          end

          counter += line.size
        end

        LineInfo.new
      end

      # Width returns the width of the textarea.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1049
      def width : Int32
        @width
      end

      def set_width(w : Int32) # ameba:disable Naming/AccessorMethodName
        # Update prompt width only if there is no prompt function; set_prompt_func
        # updates prompt width when it is configured.
        if @prompt_func.nil?
          @prompt_width = UnicodeCharWidth.width(@prompt)
        end

        # Add base style borders and padding to reserved outer width.
        reserved_outer = active_style.base.get_horizontal_frame_size

        # Add prompt width and, optionally, line number width to reserved inner width.
        reserved_inner = @prompt_width
        if @show_line_numbers
          gap = 2
          reserved_inner += num_digits(@max_height) + gap
        end

        # Ensure at least one cell for input content.
        min_width = reserved_inner + reserved_outer + 1
        input_width = Math.max(w, min_width)

        # Respect configured maximum width when set.
        if @max_width > 0
          input_width = Math.min(input_width, @max_width)
        end

        @viewport.set_width(input_width - reserved_outer)
        @width = input_width - reserved_outer - reserved_inner
        recalculate_height
      end

      def width=(w : Int32)
        set_width(w)
      end

      # Height returns the height of the textarea.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1054
      def height : Int32
        @height
      end

      def set_height(h : Int32) # ameba:disable Naming/AccessorMethodName
        if @max_height > 0
          @height = clamp(h, MIN_HEIGHT, @max_height)
          @viewport.set_height(clamp(h, MIN_HEIGHT, @max_height))
        else
          @height = Math.max(h, MIN_HEIGHT)
          @viewport.set_height(Math.max(h, MIN_HEIGHT))
        end

        reposition_view
      end

      def height=(h : Int32)
        set_height(h)
      end

      # repositionView repositions the view of the viewport based on the defined
      # scrolling behavior.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1033
      private def reposition_view
        minimum = @viewport.y_offset
        maximum = minimum + @viewport.height - 1
        row = cursor_line_number
        if row < minimum
          @viewport.scroll_up(minimum - row)
        elsif row > maximum
          @viewport.scroll_down(row - maximum)
        end
      end

      # MoveToBegin moves the cursor to the beginning of the textarea.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1060
      def move_to_begin
        @row = 0
        set_cursor_column(0)
        reposition_view
      end

      # PageUp moves the cursor one page up.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1072
      def page_up
        offset = @viewport.y_offset - cursor_line_number
        if offset < 0
          set_cursor_line_relative(offset)
          return
        end

        set_cursor_line_relative(-@height)
      end

      # PageDown moves the cursor one page down.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1077
      def page_down
        offset = cursor_line_number - @viewport.y_offset
        if offset < @height - 1
          set_cursor_line_relative(@height - 1 - offset)
          return
        end

        set_cursor_line_relative(@height)
      end

      # cursorLineNumber returns the line number that the cursor is on.
      # This accounts for soft wrapped lines.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1619
      def cursor_line_number : Int32
        line = 0
        @row.times do |i|
          # Calculate the number of lines that the current line will be split
          # into.
          line += memoized_wrap(@value[i], @width).size
        end
        line += line_info.row_offset
        line
      end

      # totalVisualLines returns the total number of display lines across all
      # logical lines, accounting for soft wraps.
      # Ported from Go: vendor/bubbles/textarea/textarea.go:1666 (v2.1.0)
      def total_visual_lines : Int32
        n = 0
        @value.each do |line|
          n += memoized_wrap(line, @width).size
        end
        n
      end

      # recalculateHeight recomputes and applies the textarea height based on
      # content when DynamicHeight is enabled. It is a no-op otherwise.
      # Ported from Go: vendor/bubbles/textarea/textarea.go:1676 (v2.1.0)
      private def recalculate_height
        return unless @dynamic_height

        min_h = Math.max(@min_height, MIN_HEIGHT)
        total = total_visual_lines
        h = Math.max(total, min_h)
        if @max_height > 0
          h = Math.min(h, @max_height)
        end
        if (max_offset = total - h)
          @viewport.y_offset > max_offset
          @viewport.set_y_offset(Math.max(0, max_offset))
        end
        set_height(h)
      end

      # atContentLimit reports whether the textarea has reached its content limit.
      # Ported from Go: vendor/bubbles/textarea/textarea.go:1694 (v2.1.0)
      private def at_content_limit : Bool
        if @max_content_height > 0
          return total_visual_lines >= @max_content_height
        end
        @max_height > 0 && @value.size >= @max_height
      end

      # visualLinesForInsert estimates how many additional visual lines would result
      # from inserting the given lines at the current cursor position.
      # Ported from Go: vendor/bubbles/textarea/textarea.go:1705 (v2.1.0)
      private def visual_lines_for_insert(lines : Array(Array(Char))) : Int32
        return 0 if lines.empty?

        current_row_visual = memoized_wrap(@value[@row], @width).size

        merged = @value[@row][0, @col] + lines[0]
        merged = merged + @value[@row][@col..] if lines.size == 1
        delta = memoized_wrap(merged, @width).size - current_row_visual

        lines.each_with_index do |content, i|
          content = content + @value[@row][@col..] if i == lines.size - 1
          delta += memoized_wrap(content, @width).size
        end

        delta
      end

      # memoizedWrap returns the wrapped lines for the given runes and width.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1607
      private def memoized_wrap(runes : Array(Char), width : Int32) : Array(Array(Char))
        input = Line.new(runes: runes, width: width)
        v, found = @cache.get(input)
        if found
          return v.as(Array(Array(Char)))
        end
        v = wrap(runes, width)
        @cache.set(input, v)
        v
      end

      # mergeLineBelow merges the current line the cursor is on with the line below.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1631
      private def merge_line_below(row : Int32)
        return if row >= @value.size - 1

        # To perform a merge, we will need to combine the two lines and then
        # re-wrap the resulting line.
        @value[row] = @value[row] + @value[row + 1]
        @value.delete_at(row + 1)

        # If we removed the last line, add a new empty line.
        if @value.empty?
          @value << [] of Char
        end

        # Adjust cursor position if necessary.
        if @row > row
          @row -= 1
        elsif @row == row && @col > @value[row].size - @value[row + 1].size
          @col = @value[row].size - @value[row + 1].size
        end
      end

      # mergeLineAbove merges the current line the cursor is on with the line above.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1651
      private def merge_line_above(row : Int32)
        return if row <= 0

        # Move cursor to the end of the previous line.
        @col = @value[row - 1].size
        @row = row - 1

        # Merge the lines.
        @value[row - 1] = @value[row - 1] + @value[row]
        @value.delete_at(row)

        # If we removed the last line, add a new empty line.
        if @value.empty?
          @value << [] of Char
        end
      end

      # splitLine splits the line at the given row and column.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1673
      private def split_line(row : Int32, col : Int32)
        return if row >= @value.size || col > @value[row].size

        # Split the line.
        left = @value[row][0...col]
        right = @value[row][col..]

        # Replace the original line with the left part and insert the right part.
        @value[row] = left
        @value.insert(row + 1, right)

        # Move cursor to the beginning of the new line.
        @row = row + 1
        @col = 0
      end

      # Blink is a command used to initialize cursor blinking.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1561
      def self.blink : Tea::Cmd
        -> { Cursor.blink.as(Tea::Msg?) }
      end

      # Paste is a command for pasting from the clipboard into the text input.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1691
      def self.paste : Tea::Cmd
        # TODO: Implement clipboard reading
        # str, err = clipboard.read_all
        # if err != nil
        #   return PasteErrMsg.new(err)
        # end
        # return PasteMsg.new(str.chars)
        -> { PasteMsg.new([] of Char).as(Tea::Msg?) }
      end

      # wrap performs word wrapping on the given runes.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1699
      private def wrap(runes : Array(Char), width : Int32) : Array(Array(Char))
        lines = [[] of Char]
        word = [] of Char
        row = 0
        spaces = 0

        # Word wrap the runes
        runes.each do |char|
          if char.whitespace?
            spaces += 1
          else
            word << char
          end

          if spaces > 0
            if UnicodeCharWidth.width(lines[row].join) + UnicodeCharWidth.width(word.join) + spaces > width
              row += 1
              lines << [] of Char
              lines[row].concat(word)
              lines[row].concat(repeat_spaces(spaces))
              spaces = 0
              word.clear
            else
              lines[row].concat(word)
              lines[row].concat(repeat_spaces(spaces))
              spaces = 0
              word.clear
            end
          else
            # If the last character is a double-width rune, then we may not be
            # able to add it to this line as it might cause us to exceed width.
            last_char_len = UnicodeCharWidth.width(word[-1].to_s)
            if UnicodeCharWidth.width(word.join) + last_char_len > width
              # If the current line has any content, let's move to the next
              # line because the current word fills up the entire line.
              if !lines[row].empty?
                row += 1
                lines << [] of Char
              end
              lines[row].concat(word)
              word.clear
            end
          end
        end

        if UnicodeCharWidth.width(lines[row].join) + UnicodeCharWidth.width(word.join) + spaces >= width
          lines << [] of Char
          lines[row + 1].concat(word)
          # We add an extra space at the end of the line to account for the
          # trailing space at the end of the previous soft-wrapped lines so that
          # behaviour when navigating is consistent and so that we don't need to
          # continually add edges to handle the last line of the wrapped input.
          spaces += 1
          lines[row + 1].concat(repeat_spaces(spaces))
        else
          lines[row].concat(word)
          spaces += 1
          lines[row].concat(repeat_spaces(spaces))
        end

        lines
      end

      # repeatSpaces returns a string of n spaces.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1764
      private def repeat_spaces(n : Int32) : Array(Char)
        Array.new(n, ' ')
      end

      # numDigits returns the number of digits in an integer.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1768
      private def num_digits(n : Int32) : Int32
        return 1 if n == 0
        count = 0
        num = abs(n)
        while num > 0
          count += 1
          num //= 10
        end
        count
      end

      # abs returns the absolute value of n.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1789
      private def abs(n : Int32) : Int32
        n < 0 ? -n : n
      end

      # view_internal returns the rendered view content of the textarea.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1317
      private def view_internal : String
        if value.empty? && @row == 0 && @col == 0 && !@placeholder.empty?
          return placeholder_view
        end

        @virtual_cursor.text_style = active_style.computed_cursor_line

        output = String::Builder.new
        style = Lipgloss::Style.new
        widest_line_number = 0
        current_line_info = line_info
        styles = active_style

        display_line = 0
        @value.each_with_index do |line, line_idx|
          wrapped_lines = memoized_wrap(line, @width)

          if @row == line_idx
            style = styles.computed_cursor_line
          else
            style = styles.computed_text
          end

          wrapped_lines.each_with_index do |wrapped_line, wrapped_idx|
            prompt = prompt_view(display_line)
            prompt = styles.computed_prompt.render(prompt)
            output << style.render(prompt)
            display_line += 1

            ln = ""
            if @show_line_numbers
              if wrapped_idx == 0 # normal line
                is_cursor_line = @row == line_idx
                output << line_number_view(line_idx + 1, is_cursor_line)
              else # soft wrapped line
                is_cursor_line = @row == line_idx
                output << line_number_view(-1, is_cursor_line)
              end
            end

            # Note the widest line number for padding purposes later.
            lnw = Lipgloss.width(ln)
            if lnw > widest_line_number
              widest_line_number = lnw
            end

            wrapped = wrapped_line.join
            strwidth = Lipgloss.width(wrapped)
            padding = @width - strwidth
            if strwidth > @width
              wrapped = wrapped.ends_with?(" ") ? wrapped[0...-1] : wrapped
              padding -= (@width - strwidth)
            end

            if @row == line_idx && current_line_info.row_offset == wrapped_idx
              wrapped_chars = wrapped.chars
              col_offset = current_line_info.column_offset
              col_offset = clamp(col_offset, 0, wrapped_chars.size)
              output << style.render(wrapped_chars[0...col_offset].join)
              if @col >= line.size && current_line_info.char_offset >= @width
                @virtual_cursor.set_char(" ")
                output << @virtual_cursor.view
              else
                ch = wrapped_chars[col_offset]? || ' '
                @virtual_cursor.set_char(ch.to_s)
                output << style.render(@virtual_cursor.view)
                if col_offset + 1 < wrapped_chars.size
                  output << style.render(wrapped_chars[(col_offset + 1)..].join)
                end
              end
            else
              output << style.render(wrapped)
            end

            output << style.render(" " * Math.max(0, padding))
            output << '\n'
          end
        end

        # Always show at least `@height` lines.
        i = 0
        while i < @height
          output << prompt_view(display_line)
          display_line += 1

          left_gutter = @end_of_buffer_character.to_s
          right_gap_width = @width - Lipgloss.width(left_gutter) + widest_line_number
          right_gap = " " * Math.max(0, right_gap_width)
          output << styles.computed_end_of_buffer.render(left_gutter + right_gap)
          output << '\n'
          i += 1
        end

        output.to_s
      end

      # View returns the rendered view of the textarea with viewport.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1415
      def view : String
        @viewport.set_content(view_internal)
        styles = active_style
        styles.base.render(@viewport.view)
      end

      # promptView renders a single line of the prompt.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1427
      private def prompt_view(display_line : Int32) : String
        prompt = @prompt
        return prompt if @prompt_func.nil?

        info = PromptInfo.new(
          line_number: display_line,
          focused: @focus
        )
        prompt = @prompt_func.as(PromptInfo -> String).call(info)
        width = Lipgloss.width(prompt)
        if width < @prompt_width
          prompt = (" " * (@prompt_width - width)) + prompt
        end

        active_style.computed_prompt.render(prompt)
      end

      # lineNumberView renders a line number.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1451
      private def line_number_view(n : Int32, is_cursor_line : Bool) : String
        return "" unless @show_line_numbers

        str = n <= 0 ? " " : n.to_s
        text_style = active_style.computed_text
        line_number_style = active_style.computed_line_number
        if is_cursor_line
          text_style = active_style.computed_cursor_line
          line_number_style = active_style.computed_cursor_line_number
        end

        digits = @max_height.to_s.size
        str = " #{str.rjust(digits)} "
        text_style.render(line_number_style.render(str))
      end

      # placeholderView renders the placeholder.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1478
      private def placeholder_view : String
        styles = active_style
        buf = String::Builder.new

        # word wrap lines
        pwordwrap = Ansi.wordwrap(@placeholder, @width, "")
        # hard wrap lines (handles lines that could not be word wrapped)
        pwrap = Ansi.hardwrap(pwordwrap, @width, true)
        # split string by new lines
        plines = pwrap.strip.split('\n')

        i = 0
        while i < @height
          is_line_number = plines.size > i
          line_style = plines.size > i ? styles.computed_cursor_line : styles.computed_placeholder

          # render prompt
          prompt = prompt_view(i)
          prompt = styles.computed_prompt.render(prompt)
          buf << line_style.render(prompt)

          # when show line numbers enabled:
          # - render line number for only the cursor line
          # - indent other placeholder lines
          if @show_line_numbers
            ln = 0
            should_render_line_number = false
            case
            when i == 0
              ln = i + 1
              should_render_line_number = true
            when plines.size > i
              should_render_line_number = true
            end
            buf << line_number_view(ln, is_line_number) if should_render_line_number
          end

          case
          when i == 0
            @virtual_cursor.text_style = styles.computed_placeholder
            line = plines[0]? || ""
            if line.empty?
              @virtual_cursor.set_char(" ")
              buf << line_style.render(@virtual_cursor.view)
            else
              first = line[0].to_s
              rest = line[1..]? || ""
              @virtual_cursor.set_char(first)
              buf << line_style.render(@virtual_cursor.view)
              buf << line_style.render(styles.computed_placeholder.render(rest))
            end
            gap = " " * Math.max(0, @width - Lipgloss.width(line))
            buf << line_style.render(gap)
          when plines.size > i
            placeholder_line = plines[i]
            gap = " " * Math.max(0, @width - Lipgloss.width(placeholder_line))
            buf << line_style.render(placeholder_line + gap)
          else
            eob = styles.computed_end_of_buffer.render(@end_of_buffer_character.to_s)
            buf << eob
          end

          buf << '\n'
          i += 1
        end

        @viewport.set_content(buf.to_s)
        styles.base.render(@viewport.view)
      end

      # Cursor returns a Tea cursor for real-cursor rendering.
      # Ported from Go: vendor/bubbles/textarea/textarea.go:Cursor.
      def cursor : Tea::Cursor?
        return nil if @use_virtual_cursor || !focused

        info = line_info
        base_style = active_style.base
        x_offset = info.char_offset +
                   Lipgloss.width(prompt_view(0)) +
                   Lipgloss.width(line_number_view(0, false)) +
                   base_style.get_margin_left +
                   base_style.get_padding_left +
                   base_style.get_border_left_size
        y_offset = cursor_line_number - @viewport.y_offset +
                   base_style.get_margin_top +
                   base_style.get_padding_top +
                   base_style.get_border_top_size

        Tea::Cursor.new(
          x: x_offset,
          y: y_offset,
          visible: true,
          style: cursor_style(@styles.cursor.shape, @styles.cursor.blink),
          color: cursor_color(@styles.cursor.color)
        )
      end

      private def cursor_style(shape : String, blink : Bool) : Tea::CursorStyle
        base = case shape.downcase
               when "underline"
                 Tea::CursorStyle::Underline
               when "bar"
                 Tea::CursorStyle::Bar
               else
                 Tea::CursorStyle::Block
               end

        return base unless blink
        case base
        when Tea::CursorStyle::Underline
          Tea::CursorStyle::UnderlineBlinking
        when Tea::CursorStyle::Bar
          Tea::CursorStyle::BarBlinking
        else
          Tea::CursorStyle::BlockBlinking
        end
      end

      private def cursor_color(raw : String?) : Colorful::Color?
        return nil unless raw

        if raw.starts_with?('#')
          return Colorful::Color.hex(raw)
        end

        idx = raw.to_i?
        return nil unless idx

        if idx <= 15
          ansi16 = {
            {0x00, 0x00, 0x00}, # black
            {0x80, 0x00, 0x00}, # maroon
            {0x00, 0x80, 0x00}, # green
            {0x80, 0x80, 0x00}, # olive
            {0x00, 0x00, 0x80}, # navy
            {0x80, 0x00, 0x80}, # purple
            {0x00, 0x80, 0x80}, # teal
            {0xc0, 0xc0, 0xc0}, # silver
            {0x80, 0x80, 0x80}, # gray
            {0xff, 0x00, 0x00}, # red
            {0x00, 0xff, 0x00}, # lime
            {0xff, 0xff, 0x00}, # yellow
            {0x00, 0x00, 0xff}, # blue
            {0xff, 0x00, 0xff}, # fuchsia
            {0x00, 0xff, 0xff}, # aqua
            {0xff, 0xff, 0xff}, # white
          }
          r, g, b = ansi16[idx.clamp(0, 15)]
        elsif idx <= 231
          n = idx - 16
          r6 = n // 36
          g6 = (n % 36) // 6
          b6 = n % 6
          r = r6 == 0 ? 0 : 55 + r6 * 40
          g = g6 == 0 ? 0 : 55 + g6 * 40
          b = b6 == 0 ? 0 : 55 + b6 * 40
        elsif idx <= 255
          gray = 8 + (idx - 232) * 10
          r = g = b = gray
        else
          return nil
        end

        Colorful::Color.new(
          r.to_f64 / 255.0,
          g.to_f64 / 255.0,
          b.to_f64 / 255.0
        )
      end

      def set_prompt_func(prompt_width : Int32, fn : PromptInfo -> String)
        @prompt_width = prompt_width
        @prompt_func = fn
      end

      def prompt_func=(fn : PromptInfo -> String)
        set_prompt_func(@prompt_width, fn)
      end

      # characterRight moves the cursor one character to the right.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:893
      private def character_right
        if @col < @value[@row].size
          set_cursor_column(@col + 1)
        else
          if @row < @value.size - 1
            @row += 1
            cursor_start
          end
        end
      end

      # characterLeft moves the cursor one character to the left.
      # If insideLine is set, the cursor is moved to the last
      # character in the previous line, instead of one past that.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:907
      private def character_left(inside_line : Bool)
        if @col == 0 && @row != 0
          @row -= 1
          cursor_end
          return unless inside_line
        end
        if @col > 0
          set_cursor_column(@col - 1)
        end
      end

      # wordLeft moves the cursor one word to the left.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:923
      private def word_left
        loop do
          character_left(true) # inside_line
          break if @col < @value[@row].size && !@value[@row][@col].whitespace?
        end

        while @col > 0
          break if @value[@row][@col - 1].whitespace?
          set_cursor_column(@col - 1)
        end
      end

      # wordRight moves the cursor one word to the right.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:942
      private def word_right
        do_word_right { |_, _| }
      end

      # doWordRight is a helper for wordRight and the various word transformation
      # functions.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:946
      private def do_word_right(& : Int32, Int32 ->)
        # Skip spaces forward.
        while @col >= @value[@row].size || @value[@row][@col].whitespace?
          break if @row == @value.size - 1 && @col == @value[@row].size
          character_right
        end

        char_idx = 0
        while @col < @value[@row].size
          break if @value[@row][@col].whitespace?
          yield char_idx, @col
          set_cursor_column(@col + 1)
          char_idx += 1
        end
      end

      # uppercaseRight changes the word to the right to uppercase.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:967
      private def uppercase_right
        do_word_right do |_, i|
          @value[@row][i] = @value[@row][i].upcase
        end
      end

      # lowercaseRight changes the word to the right to lowercase.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:974
      private def lowercase_right
        do_word_right do |_, i|
          @value[@row][i] = @value[@row][i].downcase
        end
      end

      # capitalizeRight changes the word to the right to title case.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:981
      private def capitalize_right
        do_word_right do |char_idx, i|
          if char_idx == 0
            @value[@row][i] = @value[@row][i].titlecase
          end
        end
      end

      # Update handles messages and updates the model.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1169
      def update(msg : Tea::Msg) : {Model, Tea::Cmd?}
        # If not focused, blur virtual cursor and return
        unless @focus
          @virtual_cursor.blur
          return {self, nil}
        end

        # Used to determine if the cursor should blink.
        old_row = cursor_line_number
        old_col = @col

        cmds = [] of Tea::Cmd

        # Ensure current line exists
        if @value[@row].nil?
          @value[@row] = [] of Char
        end

        # Update cache capacity if MaxHeight changed
        if @max_height > 0 && @max_height != @cache.capacity
          @cache = Internal::Memoization::MemoCache(Line, Array(Array(Char))).new(@max_height)
        end

        case msg
        when Tea::PasteMsg
          paste_msg = msg.as(Tea::PasteMsg)
          insert_runes_from_user_input(paste_msg.content.chars)
        when Tea::KeyPressMsg
          key_msg = msg.as(Tea::KeyPressMsg)
          cmd = handle_key_press(key_msg)
          # MaxHeight sentinel is an internal message, not a command.
          return {self, nil} if cmd.is_a?(MaxHeightHitMsg)
          # If handle_key_press returned a command (e.g., paste), return immediately
          return {self, cmd} if cmd
        when PasteMsg
          paste_msg = msg.as(PasteMsg)
          insert_runes_from_user_input(paste_msg.chars)
        when PasteErrMsg
          paste_err_msg = msg.as(PasteErrMsg)
          @err = paste_err_msg.error
        end

        # Make sure we set the content of the viewport before updating it.
        view_result = view_internal
        @viewport.set_content(view_result)
        vp, cmd = @viewport.update(msg)
        @viewport = vp
        cmds << cmd if cmd

        recalculate_height

        if @use_virtual_cursor
          @virtual_cursor, cmd = @virtual_cursor.update(msg)

          # If the cursor has moved, reset the blink state. This is a small UX
          # nuance that makes cursor movement obvious and feel snappy.
          new_row, new_col = cursor_line_number, @col
          if (new_row != old_row || new_col != old_col) && @virtual_cursor.mode == Cursor::Mode::Blink
            # In Crystal, blinked is a property with setter, not is_blinked
            @virtual_cursor.blinked = false
            cmd = @virtual_cursor.blink
          end
          cmds << cmd if cmd
        end

        reposition_view

        # Return batched commands
        batched = Tea.batch
        cmds.each do |lcmd|
          batched = Tea.batch(batched, lcmd)
        end
        {self, batched}
      end

      # handle_key_press processes a key press message.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1191
      private def handle_key_press(key_msg : Tea::KeyPressMsg) : Tea::Cmd? | MaxHeightHitMsg
        key_str = key_msg.keystroke

        # Check each key binding in exact Go order
        if Key.matches?(key_str, @key_map.delete_after_cursor)
          @col = clamp(@col, 0, @value[@row].size)
          if @col >= @value[@row].size
            merge_line_below(@row)
            return nil
          end
          delete_after_cursor
        elsif Key.matches?(key_str, @key_map.delete_before_cursor)
          @col = clamp(@col, 0, @value[@row].size)
          if @col <= 0
            merge_line_above(@row)
            return nil
          end
          delete_before_cursor
        elsif Key.matches?(key_str, @key_map.delete_character_backward)
          @col = clamp(@col, 0, @value[@row].size)
          if @col <= 0
            merge_line_above(@row)
            return nil
          end
          unless @value[@row].empty?
            # Delete character before cursor (Go: m.value[m.row] = append(m.value[m.row][:max(0, m.col-1)], m.value[m.row][m.col:]...))
            if @col > 0
              @value[@row] = @value[@row][0...@col - 1] + @value[@row][@col..]
              set_cursor_column(@col - 1)
            end
          end
        elsif Key.matches?(key_str, @key_map.delete_character_forward)
          if !@value[@row].empty? && @col < @value[@row].size
            # Delete character at cursor (Go: slices.Delete(m.value[m.row], m.col, m.col+1))
            @value[@row] = @value[@row][0...@col] + @value[@row][@col + 1..]
          end
          if @col >= @value[@row].size
            merge_line_below(@row)
            return nil
          end
        elsif Key.matches?(key_str, @key_map.delete_word_backward)
          if @col <= 0
            merge_line_above(@row)
            return nil
          end
          delete_word_left
        elsif Key.matches?(key_str, @key_map.delete_word_forward)
          @col = clamp(@col, 0, @value[@row].size)
          if @col >= @value[@row].size
            merge_line_below(@row)
            return nil
          end
          delete_word_right
        elsif Key.matches?(key_str, @key_map.insert_newline)
          if at_content_limit
            return MaxHeightHitMsg.new
          end
          @col = clamp(@col, 0, @value[@row].size)
          split_line(@row, @col)
        elsif Key.matches?(key_str, @key_map.line_end)
          cursor_end
        elsif Key.matches?(key_str, @key_map.line_start)
          cursor_start
        elsif Key.matches?(key_str, @key_map.character_forward)
          character_right
        elsif Key.matches?(key_str, @key_map.line_next)
          cursor_down
        elsif Key.matches?(key_str, @key_map.word_forward)
          word_right
        elsif Key.matches?(key_str, @key_map.paste)
          # Return paste command (Go: return m, Paste)
          return self.class.paste
        elsif Key.matches?(key_str, @key_map.character_backward)
          character_left(false) # inside_line = false (Go: m.characterLeft(false /* insideLine */))
        elsif Key.matches?(key_str, @key_map.line_previous)
          cursor_up
        elsif Key.matches?(key_str, @key_map.word_backward)
          word_left
        elsif Key.matches?(key_str, @key_map.input_begin)
          move_to_begin
        elsif Key.matches?(key_str, @key_map.input_end)
          move_to_end
        elsif Key.matches?(key_str, @key_map.page_up)
          page_up
        elsif Key.matches?(key_str, @key_map.page_down)
          page_down
        elsif Key.matches?(key_str, @key_map.lowercase_word_forward)
          lowercase_right
        elsif Key.matches?(key_str, @key_map.uppercase_word_forward)
          uppercase_right
        elsif Key.matches?(key_str, @key_map.capitalize_word_forward)
          capitalize_right
        elsif Key.matches?(key_str, @key_map.transpose_character_backward)
          transpose_left
        else
          # Default case (Go: m.insertRunesFromUserInput([]rune(msg.Text)))
          insert_runes_from_user_input(key_msg.text.chars)
        end

        nil
      end

      private def clamp(v : Int32, lo : Int32, hi : Int32) : Int32
        if hi < lo
          lo, hi = hi, lo
        end
        Math.min(hi, Math.max(lo, v))
      end
    end

    def self.new : Model
      Model.new
    end
  end
end
