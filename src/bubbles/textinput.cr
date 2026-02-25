require "../tea"
require "../lipgloss"
require "./key"
require "./cursor"
require "uniwidth"
require "textseg"

module Bubbles
  module TextInput
    # EchoMode sets the input behavior of the text input field.
    enum EchoMode
      Normal   # displays text as is (default)
      Password # displays EchoCharacter mask instead of actual characters
      None     # displays nothing as characters are entered
    end

    # ValidateFunc is a function that returns an error if the input is invalid.
    alias ValidateFunc = (String) -> Exception?

    # Internal messages for clipboard operations.
    class PasteMsg < Tea::Msg
      property content : String

      def initialize(@content : String); end
    end

    class PasteErrMsg < Tea::Msg
      property error : Exception

      def initialize(@error : Exception); end
    end

    # Paste is a command for pasting from the clipboard into the text input.
    def self.paste : Tea::Cmd
      -> { PasteMsg.new("").as(Tea::Msg?) }
    end

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
        runes.each do |rune|
          case rune
          when '\r', '\n'
            result.concat(@replace_newline)
          when '\t'
            result.concat(@replace_tab)
          when .control?
            # skip control characters
          else
            result << rune
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
        @value.join
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

      # SetSuggestions sets the suggestions for the input.
      def set_suggestions(suggestions : Array(String))
        @suggestions = suggestions.map(&.chars)
        update_suggestions
      end

      # CurrentSuggestion returns the currently selected suggestion.
      def current_suggestion : String
        return "" if @current_suggestion_index >= @matched_suggestions.size
        @matched_suggestions[@current_suggestion_index].join
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
        if @width <= 0 || string_width(@value.join) <= @width
          @offset = 0
          @offset_right = @value.size
          return
        end

        # Correct right offset if we've deleted characters
        @offset_right = min(@offset_right, @value.size)

        if @pos < @offset
          @offset = @pos
          w = 0
          i = 0
          runes = @value[@offset..]
          while i < runes.size && w <= @width
            w += UnicodeCharWidth.width(runes[i])
            if w <= @width + 1
              i += 1
            end
          end
          @offset_right = @offset + i
        elsif @pos >= @offset_right
          @offset_right = @pos
          w = 0
          runes = @value[0, @offset_right]
          i = runes.size - 1
          while i > 0 && w < @width
            w += UnicodeCharWidth.width(runes[i])
            if w <= @width
              i -= 1
            end
          end
          @offset = @offset_right - (runes.size - 1 - i)
        end
      end

      private def validate(runes : Array(Char)) : Exception?
        if validate_func = @validate
          validate_func.call(runes.join)
        end
      end

      private def echo_transform(v : String) : String
        case @echo_mode
        when EchoMode::Password
          @echo_character.to_s * v.size # TODO: use actual string width
        when EchoMode::None
          ""
        else
          v
        end
      end

      private def active_style : StyleState
        @focus ? @styles.focused : @styles.blurred
      end

      private def key_matches(msg : Tea::Msg, binding : Key::Binding) : Bool
        msg.is_a?(Tea::KeyPressMsg) && Key.matches?(msg, binding)
      end

      private def delete_before_cursor
        @value = @value[@pos..]
        @err = validate(@value)
        @offset = 0
        set_cursor(0)
      end

      private def delete_after_cursor
        @value = @value[0, @pos]
        @err = validate(@value)
        set_cursor(@value.size)
      end

      private def word_backward
        if @pos == 0 || @value.empty?
          return
        end

        if @echo_mode != EchoMode::Normal
          cursor_start
          return
        end

        i = @pos - 1
        while i >= 0 && @value[i].whitespace?
          set_cursor(@pos - 1)
          i -= 1
        end

        while i >= 0 && !@value[i].whitespace?
          set_cursor(@pos - 1)
          i -= 1
        end
      end

      private def word_forward
        if @pos >= @value.size || @value.empty?
          return
        end

        if @echo_mode != EchoMode::Normal
          cursor_end
          return
        end

        i = @pos
        while i < @value.size && @value[i].whitespace?
          set_cursor(@pos + 1)
          i += 1
        end

        while i < @value.size && !@value[i].whitespace?
          set_cursor(@pos + 1)
          i += 1
        end
      end

      private def delete_word_backward
        if @pos == 0 || @value.empty?
          return
        end

        if @echo_mode != EchoMode::Normal
          delete_before_cursor
          return
        end

        old_pos = @pos
        set_cursor(@pos - 1)
        while @value[@pos]?.try(&.whitespace?)
          break if @pos <= 0
          set_cursor(@pos - 1)
        end

        while @pos > 0
          if !@value[@pos].whitespace?
            set_cursor(@pos - 1)
          else
            if @pos > 0
              set_cursor(@pos + 1)
            end
            break
          end
        end

        if @pos > @value.size
          @value = @value[0, old_pos]
        else
          @value = @value[0, @pos] + @value[old_pos..]
        end
        @err = validate(@value)
        set_cursor(old_pos)
      end

      private def delete_word_forward
        if @pos >= @value.size || @value.empty?
          return
        end

        if @echo_mode != EchoMode::Normal
          delete_after_cursor
          return
        end

        old_pos = @pos
        set_cursor(@pos + 1)
        while @value[@pos]?.try(&.whitespace?)
          break if @pos >= @value.size
          set_cursor(@pos + 1)
        end

        while @pos < @value.size
          if !@value[@pos].whitespace?
            set_cursor(@pos + 1)
          else
            break
          end
        end

        if @pos > @value.size
          @value = @value[0, old_pos]
        else
          @value = @value[0, old_pos] + @value[@pos..]
        end
        @err = validate(@value)
        set_cursor(old_pos)
      end

      private def insert_runes_from_user_input(v : Array(Char))
        paste = san.sanitize(v)

        avail_space = 0
        if @char_limit > 0
          avail_space = @char_limit - @value.size
          return if avail_space <= 0
          if avail_space < paste.size
            paste = paste[0, avail_space]
          end
        end

        head = @value[0, @pos]
        tail = @value[@pos..]

        paste.each do |char|
          head << char
          @pos += 1
          if @char_limit > 0
            avail_space -= 1
            break if avail_space <= 0
          end
        end

        value = head + tail
        input_err = validate(value)
        set_value_internal(value, input_err)
      end

      private def can_accept_suggestion : Bool
        @focus && @show_suggestions && !@matched_suggestions.empty?
      end

      private def update_suggestions
        # TODO: implement
        @matched_suggestions.clear
        @current_suggestion_index = 0
      end

      private def next_suggestion
        return unless can_accept_suggestion
        @current_suggestion_index = (@current_suggestion_index + 1) % @matched_suggestions.size
      end

      private def previous_suggestion
        return unless can_accept_suggestion
        @current_suggestion_index = (@current_suggestion_index - 1) % @matched_suggestions.size
      end

      private def max(a : Int32, b : Int32) : Int32
        a > b ? a : b
      end

      private def min(a : Int32, b : Int32) : Int32
        a < b ? a : b
      end

      private def string_width(str : String) : Int32
        UnicodeCharWidth.width(str)
      end

      private def completion_view(offset : Int32) : String
        return "" unless can_accept_suggestion
        suggestion = @matched_suggestions[@current_suggestion_index]
        return "" if @value.size >= suggestion.size
        # TODO: implement styling
        suggestion[@value.size + offset..].join
      end

      private def prompt_view : String
        active_style.prompt.render(@prompt)
      end

      private def placeholder_view : String
        # TODO: implement placeholder view with styling and cursor
        @placeholder
      end

      # Init returns the initial command(s) for the model.
      def init : Tea::Cmd
        nil
      end

      # Update handles incoming messages and returns an updated model
      # along with optional commands.
      def update(msg : Tea::Msg) : {self, Tea::Cmd}
        if !@focus
          return {self, nil}
        end

        # Need to check for completion before, because key is configurable and might be double assigned
        if msg.is_a?(Tea::KeyPressMsg) && key_matches(msg, @key_map.accept_suggestion)
          if can_accept_suggestion
            @value.concat(@matched_suggestions[@current_suggestion_index][@value.size..])
            cursor_end
          end
        end

        old_pos = @pos

        case msg
        when Tea::KeyPressMsg
          case
          when key_matches(msg, @key_map.delete_word_backward)
            delete_word_backward
          when key_matches(msg, @key_map.delete_character_backward)
            @err = nil
            if @value.size > 0
              @value = @value[0, Math.max(0, @pos - 1)] + @value[@pos..]
              @err = validate(@value)
              if @pos > 0
                set_cursor(@pos - 1)
              end
            end
          when key_matches(msg, @key_map.word_backward)
            word_backward
          when key_matches(msg, @key_map.character_backward)
            if @pos > 0
              set_cursor(@pos - 1)
            end
          when key_matches(msg, @key_map.word_forward)
            word_forward
          when key_matches(msg, @key_map.character_forward)
            if @pos < @value.size
              set_cursor(@pos + 1)
            end
          when key_matches(msg, @key_map.line_start)
            cursor_start
          when key_matches(msg, @key_map.delete_character_forward)
            if @value.size > 0 && @pos < @value.size
              @value.delete_at(@pos)
              @err = validate(@value)
            end
          when key_matches(msg, @key_map.line_end)
            cursor_end
          when key_matches(msg, @key_map.delete_after_cursor)
            delete_after_cursor
          when key_matches(msg, @key_map.delete_before_cursor)
            delete_before_cursor
          when key_matches(msg, @key_map.paste)
            return {self, TextInput.paste}
          when key_matches(msg, @key_map.delete_word_forward)
            delete_word_forward
          when key_matches(msg, @key_map.next_suggestion)
            next_suggestion
          when key_matches(msg, @key_map.prev_suggestion)
            previous_suggestion
          else
            # Input one or more regular characters.
            insert_runes_from_user_input(msg.key.chars)
          end
          update_suggestions
        when Tea::PasteMsg
          insert_runes_from_user_input(msg.content.chars)
        when PasteMsg
          insert_runes_from_user_input(msg.content.chars)
        when PasteErrMsg
          @err = msg.error
        end

        cmds = [] of Tea::Cmd
        cmd = nil

        if @use_virtual_cursor
          @virtual_cursor, cmd = @virtual_cursor.update(msg)
          cmds << cmd if cmd

          # If the cursor position changed, reset the blink state.
          if old_pos != @pos && @virtual_cursor.mode == Cursor::Mode::Blink
            @virtual_cursor.is_blinked = false
            cmds << @virtual_cursor.blink
          end
        end

        handle_overflow

        if cmds.empty?
          {self, nil}
        else
          {self, -> { cmds.each(&.call); nil }}
        end
      end

      # View renders the model's current state as a string for display.
      def view : String
        # Placeholder text
        if @value.empty? && !@placeholder.empty?
          return placeholder_view
        end

        styles = active_style
        style_text = styles.text.inline(true).render

        value = @value[@offset...@offset_right]
        pos = max(0, @pos - @offset)
        v = style_text(echo_transform(value[0, pos].join))

        if pos < value.size
          char = echo_transform(value[pos].to_s)
          @virtual_cursor.set_char(char)
          v += @virtual_cursor.view
          v += style_text(echo_transform(value[pos + 1..].join))
          v += completion_view(0)
        else
          if @focus && can_accept_suggestion
            suggestion = @matched_suggestions[@current_suggestion_index]
            if value.size < suggestion.size
              @virtual_cursor.text_style = styles.suggestion
              @virtual_cursor.set_char(echo_transform(suggestion[pos].to_s))
              v += @virtual_cursor.view
              v += completion_view(1)
            else
              @virtual_cursor.set_char(" ")
              v += @virtual_cursor.view
            end
          else
            @virtual_cursor.set_char(" ")
            v += @virtual_cursor.view
          end
        end

        # If a max width and background color were set fill the empty spaces with
        # the background color.
        val_width = string_width(value.join)
        if @width > 0 && val_width <= @width
          padding = max(0, @width - val_width)
          if val_width + padding <= @width && pos < value.size
            padding += 1
          end
          v += style_text(" " * padding)
        end

        prompt_view + v
      end
    end

    # New creates a new model with default settings.
    def self.new : Model
      Model.new
    end
  end
end
