require "bubbletea"
require "./key"

module Bubbles
  module Filepicker
    struct Entry
      property name : String
      property dir : Bool # ameba:disable Naming/QueryBoolMethods

      def initialize(@name : String, @dir : Bool = false)
      end
    end

    struct KeyMap
      property select : Bubbles::Key::Binding

      def initialize(@select = Bubbles::Key.new_binding(Bubbles::Key.with_keys("enter")))
      end
    end

    class Model
      property path : String
      property current_directory : String
      property allowed_types : Array(String)
      property file_allowed : Bool # ameba:disable Naming/QueryBoolMethods
      property dir_allowed : Bool  # ameba:disable Naming/QueryBoolMethods
      property selected : Int32
      property files : Array(Entry)
      property key_map : KeyMap

      @height : Int32
      @min_idx : Int32
      @max_idx : Int32

      def initialize
        @path = ""
        @current_directory = "."
        @allowed_types = [] of String
        @file_allowed = true
        @dir_allowed = false
        @selected = 0
        @files = [] of Entry
        @key_map = KeyMap.new
        @height = 0
        @min_idx = 0
        @max_idx = 0
      end

      # SetHeight sets the height of the file picker.
      def set_height(h : Int32) # ameba:disable Naming/AccessorMethodName
        @height = h
        if @max_idx > @height - 1
          @max_idx = @min_idx + @height - 1
        end
      end

      def height=(h : Int32)
        set_height(h)
      end

      # Height returns the height of the file picker.
      def height : Int32
        @height
      end

      # DidSelectFile returns whether a user has selected a file.
      def did_select_file(msg : Tea::Msg) : {Bool, String}
        did_select, selected_path = did_select_file_internal(msg)
        if did_select && can_select(selected_path)
          return {true, selected_path}
        end
        {false, ""}
      end

      # DidSelectDisabledFile returns whether a disabled file was selected.
      def did_select_disabled_file(msg : Tea::Msg) : {Bool, String}
        did_select, selected_path = did_select_file_internal(msg)
        if did_select && !can_select(selected_path)
          return {true, selected_path}
        end
        {false, ""}
      end

      # HighlightedPath returns the currently highlighted path.
      def highlighted_path : String
        if @files.empty? || @selected < 0 || @selected >= @files.size
          return ""
        end
        File.join(@current_directory, @files[@selected].name)
      end

      private def did_select_file_internal(msg : Tea::Msg) : {Bool, String}
        return {false, ""} if @files.empty?
        return {false, ""} unless msg.is_a?(Tea::KeyPressMsg)
        return {false, ""} unless Bubbles::Key.matches?(msg, @key_map.select)

        entry = @files[@selected]?
        return {false, ""} unless entry
        selected_path = File.join(@current_directory, entry.name)

        if (!entry.dir && @file_allowed) || (entry.dir && @dir_allowed && !@path.empty?)
          return {true, selected_path}
        end
        {false, ""}
      end

      private def can_select(file : String) : Bool
        return true if @allowed_types.empty?
        @allowed_types.any? { |ext| file.ends_with?(ext) }
      end
    end

    # IsHidden reports whether a file is hidden.
    def self.hidden?(file : String) : {Bool, Exception?}
      {file.starts_with?("."), nil}
    end
  end
end
