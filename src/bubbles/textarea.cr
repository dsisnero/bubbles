require "digest/sha256"

module Bubbles
  module Textarea
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

    struct Line
      property runes : Array(Char)
      property width : Int32

      def initialize(@runes : Array(Char), @width : Int32)
      end

      def hash : String
        Digest::SHA256.hexdigest("#{runes.join}:#{@width}")
      end
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

      def view : Tea::View
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
