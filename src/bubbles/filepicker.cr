require "./key"
require "lipgloss"
require "file"

module Bubbles
  module Filepicker
    @@last_id = Atomic(Int64).new(0_i64)

    def self.next_id : Int32
      (@@last_id.add(1) + 1).to_i32
    end

    # Internal messages
    class ErrorMsg
      include Tea::Msg
      property error : Exception

      def initialize(@error : Exception); end
    end

    # Entry represents a directory entry with name and file info
    struct Entry
      property name : String
      property info : File::Info

      def initialize(@name : String, @info : File::Info); end

      def directory? : Bool
        @info.directory?
      end

      def symlink? : Bool
        @info.symlink?
      end

      def size : UInt64
        @info.size.to_u64
      end

      def permissions : File::Permissions
        @info.permissions
      end
    end

    class ReadDirMsg
      include Tea::Msg
      property id : Int32
      property entries : Array(Entry)

      def initialize(@id : Int32, @entries : Array(Entry)); end
    end

    # Constants matching Go implementation
    MARGIN_BOTTOM   = 5
    FILE_SIZE_WIDTH = 7
    PADDING_LEFT    = 2

    # KeyMap defines key bindings for each user action.
    struct KeyMap
      property go_to_top : Key::Binding
      property go_to_last : Key::Binding
      property down : Key::Binding
      property up : Key::Binding
      property page_up : Key::Binding
      property page_down : Key::Binding
      property back : Key::Binding
      property open : Key::Binding
      property select : Key::Binding

      def initialize(
        @go_to_top = Key.new_binding(Key.with_keys("g")),
        @go_to_last = Key.new_binding(Key.with_keys("G")),
        @down = Key.new_binding(Key.with_keys("j", "down", "ctrl+n")),
        @up = Key.new_binding(Key.with_keys("k", "up", "ctrl+p")),
        @page_up = Key.new_binding(Key.with_keys("K", "pgup")),
        @page_down = Key.new_binding(Key.with_keys("J", "pgdown")),
        @back = Key.new_binding(Key.with_keys("h", "backspace", "left", "esc")),
        @open = Key.new_binding(Key.with_keys("l", "right", "enter")),
        @select = Key.new_binding(Key.with_keys("enter")),
      )
      end
    end

    # DefaultKeyMap defines the default keybindings.
    def self.default_key_map : KeyMap
      KeyMap.new(
        go_to_top: Key.new_binding(Key.with_keys("g"), Key.with_help("g", "first")),
        go_to_last: Key.new_binding(Key.with_keys("G"), Key.with_help("G", "last")),
        down: Key.new_binding(Key.with_keys("j", "down", "ctrl+n"), Key.with_help("j", "down")),
        up: Key.new_binding(Key.with_keys("k", "up", "ctrl+p"), Key.with_help("k", "up")),
        page_up: Key.new_binding(Key.with_keys("K", "pgup"), Key.with_help("pgup", "page up")),
        page_down: Key.new_binding(Key.with_keys("J", "pgdown"), Key.with_help("pgdown", "page down")),
        back: Key.new_binding(Key.with_keys("h", "backspace", "left", "esc"), Key.with_help("h", "back")),
        open: Key.new_binding(Key.with_keys("l", "right", "enter"), Key.with_help("l", "open")),
        select: Key.new_binding(Key.with_keys("enter"), Key.with_help("enter", "select"))
      )
    end

    # Styles defines the possible customizations for styles in the file picker.
    struct Styles
      property disabled_cursor : Lipgloss::Style
      property cursor : Lipgloss::Style
      property symlink : Lipgloss::Style
      property directory : Lipgloss::Style
      property file : Lipgloss::Style
      property disabled_file : Lipgloss::Style
      property permission : Lipgloss::Style
      property selected : Lipgloss::Style
      property disabled_selected : Lipgloss::Style
      property file_size : Lipgloss::Style
      property empty_directory : Lipgloss::Style

      def initialize(
        @disabled_cursor = Lipgloss::Style.new,
        @cursor = Lipgloss::Style.new,
        @symlink = Lipgloss::Style.new,
        @directory = Lipgloss::Style.new,
        @file = Lipgloss::Style.new,
        @disabled_file = Lipgloss::Style.new,
        @permission = Lipgloss::Style.new,
        @selected = Lipgloss::Style.new,
        @disabled_selected = Lipgloss::Style.new,
        @file_size = Lipgloss::Style.new,
        @empty_directory = Lipgloss::Style.new,
      )
      end
    end

    # DefaultStyles defines the default styling for the file picker.
    def self.default_styles : Styles
      Styles.new(
        disabled_cursor: Lipgloss::Style.new.foreground(Lipgloss.color("247")),
        cursor: Lipgloss::Style.new.foreground(Lipgloss.color("212")),
        symlink: Lipgloss::Style.new.foreground(Lipgloss.color("36")),
        directory: Lipgloss::Style.new.foreground(Lipgloss.color("99")),
        file: Lipgloss::Style.new,
        disabled_file: Lipgloss::Style.new.foreground(Lipgloss.color("243")),
        disabled_selected: Lipgloss::Style.new.foreground(Lipgloss.color("247")),
        permission: Lipgloss::Style.new.foreground(Lipgloss.color("244")),
        selected: Lipgloss::Style.new.foreground(Lipgloss.color("212")).bold(true),
        file_size: Lipgloss::Style.new.foreground(Lipgloss.color("240")).width(FILE_SIZE_WIDTH).align(:right),
        empty_directory: Lipgloss::Style.new.foreground(Lipgloss.color("240")).padding_left(PADDING_LEFT).set_string("Bummer. No Files Found.")
      )
    end

    # Stack type for navigation history (matching Go implementation)
    class Stack
      @slice = [] of Int32

      def push(i : Int32) : Nil
        @slice << i
      end

      def pop : Int32
        @slice.pop
      end

      def length : Int32
        @slice.size
      end
    end

    # Model represents a file picker.
    class Model
      private NO_OP_CMD = -> : Tea::Msg? { nil }

      property path : String
      property current_directory : String
      property allowed_types : Array(String)
      property cursor : String
      property key_map : KeyMap
      property styles : Styles
      property show_permissions : Bool
      property show_size : Bool
      property show_hidden : Bool
      property dir_allowed : Bool
      property file_allowed : Bool

      def initialize
        @id = Filepicker.next_id
        @path = ""
        @current_directory = "."
        @allowed_types = [] of String
        @key_map = Filepicker.default_key_map
        @show_permissions = true
        @show_size = true
        @show_hidden = false
        @dir_allowed = false
        @file_allowed = true
        @file_selected = ""
        @cursor = ">"
        @styles = Filepicker.default_styles
        @auto_height = true
        @files = [] of Entry
        @selected = 0
        @selected_stack = Stack.new
        @min_idx = 0
        @max_idx = 0
        @max_stack = Stack.new
        @min_stack = Stack.new
        @height = 0
      end

      def id : Int32
        @id
      end

      def file_allowed? : Bool
        @file_allowed
      end

      def dir_allowed? : Bool
        @dir_allowed
      end

      def show_permissions? : Bool
        @show_permissions
      end

      def show_size? : Bool
        @show_size
      end

      def show_hidden? : Bool
        @show_hidden
      end

      def auto_height? : Bool
        @auto_height
      end

      # SetHeight sets the height of the file picker.
      def height=(h : Int32)
        @height = h
        if @max_idx > @height - 1
          @max_idx = @min_idx + @height - 1
        end
      end

      # Height returns the height of the file picker.
      def height : Int32
        @height
      end

      private def push_view(selected : Int32, minimum : Int32, maximum : Int32) : Nil
        @selected_stack.push(selected)
        @min_stack.push(minimum)
        @max_stack.push(maximum)
      end

      private def pop_view : {Int32, Int32, Int32}
        {@selected_stack.pop, @min_stack.pop, @max_stack.pop}
      end

      # Init initializes the file picker model.
      def init : Tea::Cmd
        read_dir(@current_directory, @show_hidden)
      end

      # Update handles user interactions within the file picker model.
      def update(msg : Tea::Msg) : {Model, Tea::Cmd}
        case msg
        when ReadDirMsg
          read_dir_msg = msg.as(ReadDirMsg)
          return {self, NO_OP_CMD} unless read_dir_msg.id == @id
          @files = read_dir_msg.entries
          @max_idx = Math.max(@max_idx, height - 1)
          {self, NO_OP_CMD}
        when Tea::WindowSizeMsg
          window_size_msg = msg.as(Tea::WindowSizeMsg)
          if @auto_height
            self.height = window_size_msg.height - MARGIN_BOTTOM
          end
          @max_idx = height - 1
          {self, NO_OP_CMD}
        when Tea::KeyPressMsg
          key_msg = msg.as(Tea::KeyPressMsg)
          handle_key_press(key_msg)
        else
          {self, NO_OP_CMD}
        end
      end

      private def handle_key_press(msg : Tea::KeyPressMsg) : {Model, Tea::Cmd}
        case
        when Key.matches?(msg, @key_map.go_to_top)
          @selected = 0
          @min_idx = 0
          @max_idx = height - 1
        when Key.matches?(msg, @key_map.go_to_last)
          @selected = @files.size - 1
          @min_idx = @files.size - height
          @max_idx = @files.size - 1
        when Key.matches?(msg, @key_map.down)
          @selected += 1
          if @selected >= @files.size
            @selected = @files.size - 1
          end
          if @selected > @max_idx
            @min_idx += 1
            @max_idx += 1
          end
        when Key.matches?(msg, @key_map.up)
          @selected -= 1
          if @selected < 0
            @selected = 0
          end
          if @selected < @min_idx
            @min_idx -= 1
            @max_idx -= 1
          end
        when Key.matches?(msg, @key_map.page_down)
          @selected += height
          if @selected >= @files.size
            @selected = @files.size - 1
          end
          @min_idx += height
          @max_idx += height

          if @max_idx >= @files.size
            @max_idx = @files.size - 1
            @min_idx = @max_idx - height
          end
        when Key.matches?(msg, @key_map.page_up)
          @selected -= height
          if @selected < 0
            @selected = 0
          end
          @min_idx -= height
          @max_idx -= height

          if @min_idx < 0
            @min_idx = 0
            @max_idx = @min_idx + height
          end
        when Key.matches?(msg, @key_map.back)
          @current_directory = File.dirname(@current_directory)
          if @selected_stack.length > 0
            @selected, @min_idx, @max_idx = pop_view
          else
            @selected = 0
            @min_idx = 0
            @max_idx = height - 1
          end
          return {self, read_dir(@current_directory, @show_hidden)}
        when Key.matches?(msg, @key_map.open)
          return {self, NO_OP_CMD} if @files.empty?

          f = @files[@selected]?
          return {self, NO_OP_CMD} unless f

          is_symlink = f.symlink?
          is_dir = f.directory?

          if is_symlink
            begin
              symlink_path = File.realpath(File.join(@current_directory, f.name))
              info = File.info?(symlink_path)
              if info && info.directory?
                is_dir = true
              end
            rescue
              # Ignore broken symlinks; keep default non-dir behavior.
            end
          end

          if (!is_dir && @file_allowed) || (is_dir && @dir_allowed)
            if Key.matches?(msg, @key_map.select)
              # Select the current path as the selection
              @path = File.join(@current_directory, f.name)
            end
          end

          return {self, NO_OP_CMD} unless is_dir

          @current_directory = File.join(@current_directory, f.name)
          push_view(@selected, @min_idx, @max_idx)
          @selected = 0
          @min_idx = 0
          @max_idx = height - 1
          return {self, read_dir(@current_directory, @show_hidden)}
        end

        {self, NO_OP_CMD}
      end

      # View returns the view of the file picker.
      def view : String
        if @files.empty?
          return @styles.empty_directory.height(height).max_height(height).to_s
        end

        String.build do |io|
          lines_rendered = 0
          @files.each_with_index do |file, idx|
            next if idx < @min_idx || idx > @max_idx

            symlink_path = ""
            is_symlink = file.symlink?
            size = humanize_bytes(file.size)
            name = file.name

            if is_symlink
              begin
                symlink_path = File.realpath(File.join(@current_directory, name))
              rescue
                symlink_path = ""
              end
            end

            disabled = !can_select(name) && !file.directory?

            if @selected == idx
              selected = ""
              if @show_permissions
                selected += " " + file_mode_to_string(file)
              end
              if @show_size
                selected += sprintf("%#{@styles.file_size.width}s", size)
              end
              selected += " " + name
              if is_symlink
                selected += " → " + symlink_path
              end
              if disabled
                io << @styles.disabled_cursor.render(@cursor) + @styles.disabled_selected.render(selected)
              else
                io << @styles.cursor.render(@cursor) + @styles.selected.render(selected)
              end
              io << '\n'
              lines_rendered += 1
              next
            end

            style = @styles.file
            if file.directory?
              style = @styles.directory
            elsif is_symlink
              style = @styles.symlink
            elsif disabled
              style = @styles.disabled_file
            end

            file_name = style.render(name)
            io << @styles.cursor.render(" ")
            if is_symlink
              file_name += " → " + symlink_path
            end
            if @show_permissions
              io << " " + @styles.permission.render(file_mode_to_string(file))
            end
            if @show_size
              io << @styles.file_size.render(size)
            end
            io << " " + file_name
            io << '\n'
            lines_rendered += 1
          end

          # Fill remaining height with newlines
          (lines_rendered..height).each do
            io << '\n'
          end
        end
      end

      # DidSelectFile returns whether a user has selected a file (on this msg).
      def did_select_file(msg : Tea::Msg) : {Bool, String}
        did_select, path = did_select_file_internal(msg)
        if did_select && can_select(path)
          return {true, path}
        end
        {false, ""}
      end

      # DidSelectDisabledFile returns whether a user tried to select a disabled file
      # (on this msg). This is necessary only if you would like to warn the user that
      # they tried to select a disabled file.
      def did_select_disabled_file(msg : Tea::Msg) : {Bool, String}
        did_select, path = did_select_file_internal(msg)
        if did_select && !can_select(path)
          return {true, path}
        end
        {false, ""}
      end

      # HighlightedPath returns the path of the currently highlighted file or directory.
      def highlighted_path : String
        if @files.empty? || @selected < 0 || @selected >= @files.size
          return ""
        end
        File.join(@current_directory, @files[@selected].name)
      end

      private def did_select_file_internal(msg : Tea::Msg) : {Bool, String}
        return {false, ""} if @files.empty?
        return {false, ""} unless msg.is_a?(Tea::KeyPressMsg)
        return {false, ""} unless Key.matches?(msg.as(Tea::KeyPressMsg), @key_map.select)

        f = @files[@selected]?
        return {false, ""} unless f

        is_symlink = f.symlink?
        is_dir = f.directory?

        if is_symlink
          begin
            symlink_path = File.realpath(File.join(@current_directory, f.name))
            info = File.info?(symlink_path)
            if info && info.directory?
              is_dir = true
            end
          rescue
            # Ignore broken symlinks; keep default non-dir behavior.
          end
        end

        if (!is_dir && @file_allowed) || (is_dir && @dir_allowed) && !@path.empty?
          return {true, @path}
        end

        {false, ""}
      end

      private def can_select(file : String) : Bool
        return true if @allowed_types.empty?
        @allowed_types.any? { |ext| file.ends_with?(ext) }
      end

      private def read_dir(path : String, show_hidden : Bool) : Tea::Cmd
        -> : Tea::Msg? {
          begin
            entries = [] of Entry
            Dir.children(path).each do |name|
              begin
                info = File.info(File.join(path, name), follow_symlinks: false)
                entries << Entry.new(name, info)
              rescue
                # Match Go's os.DirEntry.Info() behavior in view/update:
                # skip unreadable/broken entries instead of failing the whole dir.
              end
            end

            # Sort: directories first, then alphabetical
            entries.sort! do |a, b|
              if a.directory? == b.directory?
                a.name <=> b.name
              else
                a.directory? ? -1 : 1
              end
            end

            unless show_hidden
              entries = entries.reject do |entry|
                hidden, _ = Filepicker.hidden?(entry.name)
                hidden
              end
            end

            ReadDirMsg.new(@id, entries)
          rescue ex
            ErrorMsg.new(ex)
          end
        }
      end

      private def humanize_bytes(bytes : UInt64) : String
        # Simple humanize implementation matching Go's humanize.Bytes
        units = ["B", "KB", "MB", "GB", "TB", "PB", "EB"]
        return "0 B" if bytes == 0

        i = 0
        size = bytes.to_f
        while size >= 1024 && i < units.size - 1
          size /= 1024
          i += 1
        end

        format = i == 0 ? "%.0f %s" : "%.1f %s"
        sprintf(format, size, units[i]).gsub(" ", "")
      end

      private def file_mode_to_string(entry : Entry) : String
        mode = entry.permissions
        # Simplified mode string representation
        str = String.build do |io|
          io << (mode.owner_read? ? 'r' : '-')
          io << (mode.owner_write? ? 'w' : '-')
          io << (mode.owner_execute? ? 'x' : '-')
          io << (mode.group_read? ? 'r' : '-')
          io << (mode.group_write? ? 'w' : '-')
          io << (mode.group_execute? ? 'x' : '-')
          io << (mode.other_read? ? 'r' : '-')
          io << (mode.other_write? ? 'w' : '-')
          io << (mode.other_execute? ? 'x' : '-')
        end
        prefix = if entry.directory?
                   'd'
                 elsif entry.symlink?
                   'l'
                 else
                   '-'
                 end
        "#{prefix}#{str}"
      end
    end

    # IsHidden reports whether a file is hidden.
    def self.hidden?(file : String) : {Bool, Exception?}
      # Unix implementation (matching hidden_unix.go)
      {file.starts_with?("."), nil}
    end

    # New returns a new filepicker model with default styling and key bindings.
    def self.new : Model
      Model.new
    end
  end
end
