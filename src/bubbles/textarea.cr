require "digest/sha256"
require "bubbletea"
require "./cursor"
require "./key"
require "./viewport"
require "./internal/memoization"
require "./internal/runeutil"

module Bubbles
  module Textarea
    # Constants ported from Go: vendor/bubbles/textarea/textarea.go:32-38
    DEFAULT_CHAR_LIMIT =     0 # no limit
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
      # TODO: Implement proper lipgloss styles
      focused = StyleState.new
      blurred = StyleState.new
      cursor = CursorStyle.new
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
      property prompt : String
      property placeholder : String
      property char_limit : Int32
      property width : Int32
      property height : Int32
      property row : Int32
      property col : Int32

      @value : Array(Array(Char))
      @scroll_y_offset : Int32
      @prompt_func : (PromptInfo -> String)?
      @prompt_width : Int32
      @styles : Styles
      @focus : Bool
      @rsan : Internal::Runeutil::Sanitizer?
      @cache : Internal::Memoization::MemoCache(Line, Array(Array(Char)))
      @show_line_numbers : Bool
      @key_map : KeyMap

      def initialize
        @prompt = "> "
        @placeholder = ""
        @char_limit = 0
        @width = 40
        @height = 6
        @row = 0
        @col = 0
        @value = [([] of Char)]
        @scroll_y_offset = 0
        @prompt_func = nil
        @prompt_width = 0
        @styles = Styles.new(
          focused: StyleState.new,
          blurred: StyleState.new,
          cursor: CursorStyle.new
        )
        @focus = false
        @rsan = nil
        @cache = Internal::Memoization::MemoCache(Line, Array(Array(Char))).new(99)
        @show_line_numbers = false
        @key_map = Textarea.default_key_map
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
      def focus
        @focus = true
        # TODO: Implement virtual_cursor.focus
      end

      # Blur removes the focus state on the model. When the model is blurred it can
      # not receive keyboard input and the cursor will be hidden.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:731
      def blur
        @focus = false
        # TODO: Implement virtual_cursor.blur
      end

      # san returns the rune sanitizer for the model.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:781
      private def san : Internal::Runeutil::Sanitizer
        if @rsan.nil?
          # Textinput has all its input on a single line so collapse
          # newlines/tabs to single spaces.
          @rsan = Internal::Runeutil::Sanitizer.new
        end
        @rsan.as(Internal::Runeutil::Sanitizer)
      end

      def set_value(s : String) # ameba:disable Naming/AccessorMethodName
        lines = s.split('\n').map(&.chars)
        @value = lines.empty? ? [([] of Char)] : lines
        @row = @value.size - 1
        @col = @value[@row].size
      end

      def value=(s : String)
        set_value(s)
      end

      def value : String
        @value.map(&.join).join("\n")
      end

      def insert_string(s : String)
        s.each_char { |char| insert_rune(char) }
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

        return if lines.empty?

        # Save the remainder of the original line at the current
        # cursor position.
        tail = @value[@row][@col..]? || [] of Char

        # Paste the first line at the current cursor position.
        @value[@row] = @value[@row][0...@col] + lines[0]
        @col += lines[0].size

        if (num_extra_lines = lines.size - 1) > 0
          # Add the new lines.
          # We try to reuse the slice if there's already space.
          new_grid = @value.dup
          if new_grid.size + num_extra_lines <= new_grid.capacity
            # Can reuse the extra space (Crystal arrays don't expose capacity like Go slices)
            # Just append nil elements
            num_extra_lines.times { new_grid << [] of Char }
          else
            # No space left; need a new slice.
            new_grid = Array(Array(Char)).new(@value.size + num_extra_lines) { [] of Char }
            new_grid[0..@row] = @value[0..@row]
          end
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
        @value.sum(&.size).to_i32
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
        return if @row <= 0
        @row -= 1
        @col = Math.min(@col, @value[@row].size)
      end

      def cursor_down
        return if @row >= @value.size - 1
        @row += 1
        @col = Math.min(@col, @value[@row].size)
      end

      def set_cursor_column(c : Int32) # ameba:disable Naming/AccessorMethodName
        @col = clamp(c, 0, @value[@row].size)
      end

      def cursor_column=(c : Int32)
        set_cursor_column(c)
      end

      def move_to_begin
        @row = 0
        @col = 0
      end

      # MoveToEnd moves the cursor to the end of the textarea.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1066
      def move_to_end
        @row = @value.size - 1
        @col = @value[@row].size
        # TODO: Implement viewport.goto_bottom
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

      # LineInfo returns the number of characters from the start of the
      # (soft-wrapped) line and the (soft-wrapped) line width.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:992
      def line_info : LineInfo
        # TODO: Implement proper LineInfo with memoizedWrap
        # For now, return a simple implementation
        line_chars = @value[@row]
        width = line_chars.size.to_i32
        LineInfo.new(
          width: width,
          char_width: width,
          height: 1,
          start_column: 0,
          column_offset: @col,
          row_offset: 0,
          char_offset: @col
        )
      end

      # Width returns the width of the textarea.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1049
      def width : Int32
        @width
      end

      def set_width(w : Int32) # ameba:disable Naming/AccessorMethodName
        @width = w
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
        @height = h
      end

      def height=(h : Int32)
        set_height(h)
      end

      # repositionView repositions the view of the viewport based on the defined
      # scrolling behavior.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1033
      private def reposition_view
        # TODO: Implement viewport integration
        # minimum = @viewport.y_offset
        # maximum = minimum + @viewport.height - 1
        # if row = cursor_line_number; row < minimum
        #   @viewport.scroll_up(minimum - row)
        # elsif row > maximum
        #   @viewport.scroll_down(row - maximum)
        # end
      end

      # MoveToBegin moves the cursor to the beginning of the textarea.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1060
      def move_to_begin
        @row = 0
        @col = 0
        # TODO: Implement viewport.goto_top
      end

      # PageUp moves the cursor one page up.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1072
      def page_up
        # TODO: Implement viewport.view_up
      end

      # PageDown moves the cursor one page down.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1077
      def page_down
        # TODO: Implement viewport.view_down
      end

      # cursorLineNumber returns the line number that the cursor is on.
      # This accounts for soft wrapped lines.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1619
      private def cursor_line_number : Int32
        line = 0
        @row.times do |i|
          # Calculate the number of lines that the current line will be split
          # into.
          line += memoized_wrap(@value[i], @width).size
        end
        line += line_info.row_offset
        line
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
      def self.blink : Tea::Msg
        Cursor.blink
      end

      # Paste is a command for pasting from the clipboard into the text input.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1691
      def self.paste : Tea::Msg
        # TODO: Implement clipboard reading
        # str, err = clipboard.read_all
        # if err != nil
        #   return PasteErrMsg.new(err)
        # end
        # return PasteMsg.new(str.chars)
        PasteMsg.new([] of Char)
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
            # TODO: Implement proper Unicode width calculation
            # For now, use simple character count
            if lines[row].size + word.size + spaces > width
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
            # TODO: Implement proper Unicode width calculation for double-width runes
            # For now, use simple character count
            if word.size + 1 > width
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

        # TODO: Implement proper Unicode width calculation
        # For now, use simple character count
        if lines[row].size + word.size + spaces >= width
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

       # view returns the rendered view of the textarea.
       # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1317
       def view : String
         if value.empty? && @row == 0 && @col == 0 && !@placeholder.empty?
           return placeholder_view
         end

         # TODO: Implement virtual_cursor.text_style = active_style.computed_cursor_line

         output = [] of String
         style = Lipgloss::Style.new
         new_lines = 0
         widest_line_number = 0
         li = line_info
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
             prompt_str = prompt_view(display_line)
             prompt_str = styles.computed_prompt.render(prompt_str)
             output << style.render(prompt_str)
             display_line += 1
            # prompt_str = styles.computed_prompt.render(prompt_str)
            prompt_str = "" # Placeholder for now
            output << "#{style}#{prompt_str}"
            display_line += 1

            if @show_line_numbers
              ln = ""
              if wrapped_idx == 0 # normal line
                is_cursor_line = @row == line_idx
                ln = line_number_view(line_idx + 1, is_cursor_line)
              else # soft wrapped line
                is_cursor_line = @row == line_idx
                ln = line_number_view(-1, is_cursor_line)
              end
              output << ln

              # Note the widest line number for padding purposes later.
              lnw = ln.size # TODO: Implement uniseg.string_width for proper Unicode width
              if lnw > widest_line_number
                widest_line_number = lnw
              end
            end

            # strwidth = wrapped_line.size # TODO: Implement uniseg.string_width for proper Unicode width
            # TODO: Add padding when we have proper Unicode width calculation
            # padding = @width - strwidth
            # if padding > 0
            #   output << wrapped_line.join + " " * padding
            # else
            #   output << wrapped_line.join
            # end
            output << wrapped_line.join

            # Add newline unless this is the last wrapped line of the last line
            unless wrapped_idx == wrapped_lines.size - 1 && line_idx == @value.size - 1
              output << "\n"
              new_lines += 1
            end
          end
        end

        output.join
      end

      # View returns the rendered view of the textarea with viewport.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1415
      # TODO: Implement View method - currently commented out due to Crystal syntax issues
      # with capital letter method names and return type annotations
      # def view_with_viewport : String
      #   # XXX: This is a workaround for the case where the viewport hasn't
      #   # been initialized yet like during the initial render. In that case,
      #   # we need to render the view again because Update hasn't been called
      #   # yet to set the content of the viewport.
      #   # TODO: Implement viewport.set_content(view)
      #   view_result = view
      #   # TODO: Implement viewport.view
      #   viewport_view = view_result
      #   styles = active_style
      #   # TODO: Implement styles.base.render(viewport_view)
      #   viewport_view
      # end

      # promptView renders a single line of the prompt.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1427
      private def prompt_view(display_line : Int32) : String
        prompt = @prompt
        return prompt if @prompt_func.nil?

        info = PromptInfo.new(
          line_number: display_line,
          focused: @focus
        )
        @prompt_func.as(PromptInfo -> String).call(info)
      end

      # lineNumberView renders a line number.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1451
      private def line_number_view(n : Int32, is_cursor_line : Bool) : String
        if n <= 0
          # Soft-wrapped line
          return "  " # Two spaces for alignment
        end

        line_num_str = n.to_s
        if is_cursor_line
          # TODO: Implement styles.computed_cursor_line_number.render(line_num_str)
          line_num_str
        else
          # TODO: Implement styles.computed_line_number.render(line_num_str)
          line_num_str
        end
      end

      # placeholderView renders the placeholder.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1478
      private def placeholder_view : String
        # TODO: Implement styles.computed_placeholder.render(@placeholder)
        @placeholder
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
          # If handle_key_press returned a command (e.g., paste), return immediately
          return {self, cmd} if cmd
          # If handle_key_press returned MaxHeightHitMsg, return immediately (Go parity)
          return {self, nil} if cmd.is_a?(MaxHeightHitMsg)
        when PasteMsg
          paste_msg = msg.as(PasteMsg)
          insert_runes_from_user_input(paste_msg.chars)
        when PasteErrMsg
          paste_err_msg = msg.as(PasteErrMsg)
          @err = paste_err_msg.error
        end

        # Make sure we set the content of the viewport before updating it.
        view_result = view
        @viewport.set_content(view_result)
        vp, cmd = @viewport.update(msg)
        @viewport = vp
        cmds << cmd

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
          cmds << cmd
        end

        reposition_view

        # Return batched commands
        {self, Tea.batch(cmds)}
      end

      # handle_key_press processes a key press message.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:1191
      private def handle_key_press(key_msg : Tea::KeyPressMsg) : Tea::Cmd?
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
          # Check MaxHeight constraint (Go: if m.MaxHeight > 0 && len(m.value) >= m.MaxHeight)
          if @max_height > 0 && @value.size >= @max_height
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
          return Textarea.paste
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
