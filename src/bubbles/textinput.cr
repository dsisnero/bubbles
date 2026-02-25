require "../tea"
require "../lipgloss"
require "./key"
require "./cursor"
require "uniwidth"
require "uni_text_seg"

module Bubbles
  module TextInput
    # EchoMode sets the input behavior of the text input field.
    enum EchoMode
      Normal   # displays text as is (default)
      Password # displays EchoCharacter mask instead of actual characters
      None     # displays nothing as characters are entered
    end

    # ValidateFunc is a function that returns an error if the input is invalid.
    alias ValidateFunc = (String) -> Error?

    # KeyMap is the key bindings for different actions within the textinput.
    struct KeyMap
      property character_forward : Key::Binding
      property character_backward : Key::Binding
      property word_forward : Key::Binding
      property word_backward : Key::Binding
      property delete_word_backward : Key::Binding
      property delete_word_forward : Key::Binding
      property delete_after_cursor : Key::Binding
      property delete_before_cursor : Key::Binding
      property delete_character_backward : Key::Binding
      property delete_character_forward : Key::Binding
      property line_start : Key::Binding
      property line_end : Key::Binding
      property paste : Key::Binding
      property accept_suggestion : Key::Binding
      property next_suggestion : Key::Binding
      property prev_suggestion : Key::Binding

      def initialize(
        @character_forward = Key::Binding.new,
        @character_backward = Key::Binding.new,
        @word_forward = Key::Binding.new,
        @word_backward = Key::Binding.new,
        @delete_word_backward = Key::Binding.new,
        @delete_word_forward = Key::Binding.new,
        @delete_after_cursor = Key::Binding.new,
        @delete_before_cursor = Key::Binding.new,
        @delete_character_backward = Key::Binding.new,
        @delete_character_forward = Key::Binding.new,
        @line_start = Key::Binding.new,
        @line_end = Key::Binding.new,
        @paste = Key::Binding.new,
        @accept_suggestion = Key::Binding.new,
        @next_suggestion = Key::Binding.new,
        @prev_suggestion = Key::Binding.new,
      )
      end
    end

    # DefaultKeyMap is the default set of key bindings for navigating and acting
    # upon the textinput.
    def self.default_key_map : KeyMap
      KeyMap.new(
        character_forward: Key.new_binding(Key.with_keys("right", "ctrl+f")),
        character_backward: Key.new_binding(Key.with_keys("left", "ctrl+b")),
        word_forward: Key.new_binding(Key.with_keys("alt+right", "ctrl+right", "alt+f")),
        word_backward: Key.new_binding(Key.with_keys("alt+left", "ctrl+left", "alt+b")),
        delete_word_backward: Key.new_binding(Key.with_keys("alt+backspace", "ctrl+w")),
        delete_word_forward: Key.new_binding(Key.with_keys("alt+delete", "alt+d")),
        delete_after_cursor: Key.new_binding(Key.with_keys("ctrl+k")),
        delete_before_cursor: Key.new_binding(Key.with_keys("ctrl+u")),
        delete_character_backward: Key.new_binding(Key.with_keys("backspace", "ctrl+h")),
        delete_character_forward: Key.new_binding(Key.with_keys("delete", "ctrl+d")),
        line_start: Key.new_binding(Key.with_keys("home", "ctrl+a")),
        line_end: Key.new_binding(Key.with_keys("end", "ctrl+e")),
        paste: Key.new_binding(Key.with_keys("ctrl+v")),
        accept_suggestion: Key.new_binding(Key.with_keys("tab")),
        next_suggestion: Key.new_binding(Key.with_keys("down", "ctrl+n")),
        prev_suggestion: Key.new_binding(Key.with_keys("up", "ctrl+p"))
      )
    end

    # Styles are the styles for the textarea, separated into focused and blurred
    # states. The appropriate styles will be chosen based on the focus state of
    # the textarea.
    struct Styles
      property focused : StyleState
      property blurred : StyleState
      property cursor : CursorStyle

      def initialize(@focused = StyleState.new, @blurred = StyleState.new, @cursor = CursorStyle.new)
      end
    end

    # StyleState that will be applied to the text area.
    #
    # StyleState can be applied to focused and unfocused states to change the styles
    # depending on the focus state.
    struct StyleState
      property text : Lipgloss::Style
      property placeholder : Lipgloss::Style
      property suggestion : Lipgloss::Style
      property prompt : Lipgloss::Style

      def initialize(
        @text = Lipgloss::Style.new,
        @placeholder = Lipgloss::Style.new,
        @suggestion = Lipgloss::Style.new,
        @prompt = Lipgloss::Style.new,
      )
      end
    end

    # CursorStyle is the style for real and virtual cursors.
    struct CursorStyle
      # Color styles the cursor block.
      #
      # For real cursors, the foreground color set here will be used as the
      # cursor color.
      property color : String

      # Shape is the cursor shape. The following shapes are available:
      #
      # - Tea::CursorShape::Block
      # - Tea::CursorShape::Underline
      # - Tea::CursorShape::Bar
      #
      # This is only used for real cursors.
      property shape : String

      # CursorBlink determines whether or not the cursor should blink.
      property? blink : Bool

      # BlinkSpeed is the speed at which the virtual cursor blinks. This has no
      # effect on real cursors as well as no effect if the cursor is set not to
      # blink.
      #
      # By default, the blink speed is set to about 500ms.
      property blink_speed : Time::Span

      def initialize(
        @color = "7",
        @shape = "block",
        @blink = true,
        @blink_speed = 500.milliseconds,
      )
      end
    end

    # DefaultStyles returns the default styles for focused and blurred states for
    # the textarea.
    def self.default_styles(is_dark : Bool) : Styles
      # TODO: implement proper styling with lipgloss
      Styles.new
    end

    # DefaultLightStyles returns the default styles for a light background.
    def self.default_light_styles : Styles
      default_styles(false)
    end

    # DefaultDarkStyles returns the default styles for a dark background.
    def self.default_dark_styles : Styles
      default_styles(true)
    end

    # Sanitizer is a helper for bubble widgets that want to process
    # runes from input key messages.
    class Sanitizer
      property replace_newline : Array(Char)
      property replace_tab : Array(Char)

      def initialize(@replace_newline = ['\n'], @replace_tab = [' ', ' ', ' ', ' '])
      end

      def sanitize(runes : Array(Char)) : Array(Char)
        result = [] of Char
        runes.each do |r|
          case r
          when '\r', '\n'
            result.concat(@replace_newline)
          when '\t'
            result.concat(@replace_tab)
          when .control?
            # skip control characters
          else
            result << r
          end
        end
        result
      end
    end

    # Model is the Bubble Tea model for this text input element.
    class Model
      include Tea::Model

      property err : Exception?
      property prompt : String
      property placeholder : String
      property echo_mode : EchoMode
      property echo_character : Char
      property char_limit : Int32
      property width : Int32
      property key_map : KeyMap
      property? show_suggestions : Bool
      property validate : ValidateFunc?
      property styles : Styles
      property rsan : Sanitizer?

      # Private fields
      property value : Array(Char)
      property focus : Bool
      property pos : Int32
      property offset : Int32
      property offset_right : Int32
      property suggestions : Array(Array(Char))
      property matched_suggestions : Array(Array(Char))
      property current_suggestion_index : Int32
      property use_virtual_cursor : Bool
      property virtual_cursor : Cursor::Model

      # TODO: rune sanitizer
      # TODO: styles

      # New creates a new model with default settings.
      def initialize
        @prompt = "> "
        @placeholder = ""
        @echo_mode = EchoMode::Normal
        @echo_character = '*'
        @char_limit = 0
        @width = 0
        @key_map = TextInput.default_key_map
        @show_suggestions = false
        @validate = nil
        @value = [] of Char
        @focus = false
        @pos = 0
        @offset = 0
        @offset_right = 0
        @suggestions = [] of Array(Char)
        @matched_suggestions = [] of Array(Char)
        @current_suggestion_index = 0
        @use_virtual_cursor = true
        @virtual_cursor = Cursor::Model.new
        @styles = TextInput.default_dark_styles
        @rsan = nil
        # TODO: update virtual cursor style
      end

      # san initializes or retrieves the rune sanitizer.
      private def san : Sanitizer
        unless rsan = @rsan
          # Textinput has all its input on a single line so collapse
          # newlines/tabs to single spaces.
          @rsan = Sanitizer.new(
            replace_newline: [' '],
            replace_tab: [' ']
          )
          rsan = @rsan.not_nil!
        end
        rsan
      end

      # Value returns the value of the text input.
      def value : String
        String.new(@value)
      end

      # SetValue sets the value of the text input.
      def set_value(s : String)
        # Clean up any special characters in the input provided by the
        # caller. This avoids bugs due to e.g. tab characters and whatnot.
        runes = s.chars
        sanitized = san.sanitize(runes)
        err = validate(sanitized)
        set_value_internal(sanitized, err)
      end

      private def set_value_internal(runes : Array(Char), err : Exception?)
        @err = err
        empty = @value.empty?

        if @char_limit > 0 && runes.size > @char_limit
          @value = runes[0, @char_limit]
        else
          @value = runes
        end
        if (@pos == 0 && empty) || @pos > @value.size
          set_cursor(@value.size)
        end
        handle_overflow
      end

      # Position returns the cursor position.
      def position : Int32
        @pos
      end

      # SetCursor moves the cursor to the given position. If the position is
      # out of bounds the cursor will be moved to the start or end accordingly.
      def set_cursor(pos : Int32)
        @pos = clamp(pos, 0, @value.size)
        handle_overflow
      end

      # CursorStart moves the cursor to the start of the input field.
      def cursor_start
        set_cursor(0)
      end

      # CursorEnd moves the cursor to the end of the input field.
      def cursor_end
        set_cursor(@value.size)
      end

      # Focused returns the focus state on the model.
      def focused? : Bool
        @focus
      end

      # Focus sets the focus state on the model. When the model is in focus it can
      # receive keyboard input and the cursor will be shown.
      def focus : Tea::Cmd
        @focus = true
        @virtual_cursor.focus
      end

      # Blur removes the focus state on the model. When the model is blurred it can
      # not receive keyboard input and the cursor will be hidden.
      def blur
        @focus = false
        @virtual_cursor.blur
      end

      # Reset sets the input to its default state with no input.
      def reset
        @value.clear
        set_cursor(0)
      end

      private def clamp(value : Int32, min : Int32, max : Int32) : Int32
        if value < min
          min
        elsif value > max
          max
        else
          value
        end
      end

      private def handle_overflow
        # TODO: implement
      end

      private def validate(runes : Array(Char)) : Exception?
        if validate_func = @validate
          validate_func.call(String.new(runes))
        end
      end

      # Init returns the initial command(s) for the model.
      def init : Tea::Cmd
        nil
      end

      # Update handles incoming messages and returns an updated model
      # along with optional commands.
      def update(msg : Tea::Msg) : {self, Tea::Cmd}
        {self, nil}
      end

      # View renders the model's current state as a string for display.
      def view : String
        ""
      end
    end

    # New creates a new model with default settings.
    def self.new : Model
      Model.new
    end
  end
end
