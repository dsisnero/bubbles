require "digest/sha256"
require "./cursor"
require "./key"
require "./viewport"
require "./internal/memoization"
require "./internal/runeutil"

module Bubbles
  module Textarea
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
      property blink : Bool # ameba:disable Naming/QueryBoolMethods
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
      property base : String               # TODO: Use lipgloss.Style
      property text : String               # TODO: Use lipgloss.Style
      property line_number : String        # TODO: Use lipgloss.Style
      property cursor_line_number : String # TODO: Use lipgloss.Style
      property cursor_line : String        # TODO: Use lipgloss.Style
      property end_of_buffer : String      # TODO: Use lipgloss.Style
      property placeholder : String        # TODO: Use lipgloss.Style
      property prompt : String             # TODO: Use lipgloss.Style

      def initialize(
        @base : String = "",
        @text : String = "",
        @line_number : String = "",
        @cursor_line_number : String = "",
        @cursor_line : String = "",
        @end_of_buffer : String = "",
        @placeholder : String = "",
        @prompt : String = "",
      )
      end

      # computedCursorLine returns the computed style for the cursor line.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:202
      def computed_cursor_line : String
        # TODO: Implement lipgloss style inheritance
        @cursor_line
      end

      # computedCursorLineNumber returns the computed style for the cursor line number.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:206
      def computed_cursor_line_number : String
        # TODO: Implement lipgloss style inheritance
        @cursor_line_number
      end

      # computedEndOfBuffer returns the computed style for the end of buffer character.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:213
      def computed_end_of_buffer : String
        # TODO: Implement lipgloss style inheritance
        @end_of_buffer
      end

      # computedLineNumber returns the computed style for line numbers.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:217
      def computed_line_number : String
        # TODO: Implement lipgloss style inheritance
        @line_number
      end

      # computedPlaceholder returns the computed style for the placeholder.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:221
      def computed_placeholder : String
        # TODO: Implement lipgloss style inheritance
        @placeholder
      end

      # computedPrompt returns the computed style for the prompt.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:225
      def computed_prompt : String
        # TODO: Implement lipgloss style inheritance
        @prompt
      end

      # computedText returns the computed style for text.
      # Ported exactly from Go: vendor/bubbles/textarea/textarea.go:229
      def computed_text : String
        # TODO: Implement lipgloss style inheritance
        @text
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
      end

      def self.new : Model
        m = allocate
        m.initialize
        m
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

      def move_to_end
        @row = @value.size - 1
        @col = @value[@row].size
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

      def line_info : LineInfo
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

      def set_width(w : Int32) # ameba:disable Naming/AccessorMethodName
        @width = w
      end

      def width=(w : Int32)
        set_width(w)
      end

      def set_height(h : Int32) # ameba:disable Naming/AccessorMethodName
        @height = h
      end

      def height=(h : Int32)
        set_height(h)
      end

      def view : String
        rendered = @value.map(&.join)
        return @placeholder if rendered.empty? || (rendered.size == 1 && rendered[0].empty? && !@placeholder.empty?)

        if @height > 0
          @scroll_y_offset = Math.max(0, @row - @height + 1)
          rendered = rendered[@scroll_y_offset, Math.min(@height, rendered.size - @scroll_y_offset)]? || [] of String
        end

        rendered.join("\n")
      end

      def set_prompt_func(prompt_width : Int32, fn : PromptInfo -> String)
        @prompt_width = prompt_width
        @prompt_func = fn
      end

      def prompt_func=(fn : PromptInfo -> String)
        set_prompt_func(@prompt_width, fn)
      end

      private def clamp(v : Int32, lo : Int32, hi : Int32) : Int32
        return lo if v < lo
        return hi if v > hi
        v
      end
    end

    def self.new : Model
      Model.new
    end
  end
end
