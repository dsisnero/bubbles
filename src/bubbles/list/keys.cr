require "../key"

module Bubbles
  module List
    struct KeyMap
      property cursor_up : Key::Binding
      property cursor_down : Key::Binding
      property next_page : Key::Binding
      property prev_page : Key::Binding
      property go_to_start : Key::Binding
      property go_to_end : Key::Binding
      property filter : Key::Binding
      property clear_filter : Key::Binding
      property cancel_while_filtering : Key::Binding
      property accept_while_filtering : Key::Binding
      property show_full_help : Key::Binding
      property close_full_help : Key::Binding
      property quit : Key::Binding
      property force_quit : Key::Binding

      def initialize(
        @cursor_up = Key::Binding.new,
        @cursor_down = Key::Binding.new,
        @next_page = Key::Binding.new,
        @prev_page = Key::Binding.new,
        @go_to_start = Key::Binding.new,
        @go_to_end = Key::Binding.new,
        @filter = Key::Binding.new,
        @clear_filter = Key::Binding.new,
        @cancel_while_filtering = Key::Binding.new,
        @accept_while_filtering = Key::Binding.new,
        @show_full_help = Key::Binding.new,
        @close_full_help = Key::Binding.new,
        @quit = Key::Binding.new,
        @force_quit = Key::Binding.new,
      )
      end
    end

    def self.default_key_map : KeyMap
      KeyMap.new(
        cursor_up: Key.new_binding(Key.with_keys("up", "k"), Key.with_help("↑/k", "up")),
        cursor_down: Key.new_binding(Key.with_keys("down", "j"), Key.with_help("↓/j", "down")),
        prev_page: Key.new_binding(Key.with_keys("left", "h", "pgup", "b", "u"), Key.with_help("←/h/pgup", "prev page")),
        next_page: Key.new_binding(Key.with_keys("right", "l", "pgdown", "f", "d"), Key.with_help("→/l/pgdn", "next page")),
        go_to_start: Key.new_binding(Key.with_keys("home", "g"), Key.with_help("g/home", "go to start")),
        go_to_end: Key.new_binding(Key.with_keys("end", "G"), Key.with_help("G/end", "go to end")),
        filter: Key.new_binding(Key.with_keys("/"), Key.with_help("/", "filter")),
        clear_filter: Key.new_binding(Key.with_keys("esc"), Key.with_help("esc", "clear filter")),
        cancel_while_filtering: Key.new_binding(Key.with_keys("esc"), Key.with_help("esc", "cancel")),
        accept_while_filtering: Key.new_binding(
          Key.with_keys("enter", "tab", "shift+tab", "ctrl+k", "up", "ctrl+j", "down"),
          Key.with_help("enter", "apply filter")
        ),
        show_full_help: Key.new_binding(Key.with_keys("?"), Key.with_help("?", "more")),
        close_full_help: Key.new_binding(Key.with_keys("?"), Key.with_help("?", "close help")),
        quit: Key.new_binding(Key.with_keys("q", "esc"), Key.with_help("q", "quit")),
        force_quit: Key.new_binding(Key.with_keys("ctrl+c"))
      )
    end
  end
end
