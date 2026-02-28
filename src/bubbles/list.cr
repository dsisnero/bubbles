require "bubbletea"
require "lipgloss"
require "./help"
require "./key"
require "./paginator"
require "./spinner"
require "./textinput"
require "./cursor"
require "./list/keys"
require "./list/style"

module Bubbles
  module List
    module Item
      abstract def filter_value : String
    end

    module ItemDelegate
      abstract def render(w : IO, m : Model, index : Int32, item : Item)
      abstract def height : Int32
      abstract def spacing : Int32
      abstract def update(msg : Tea::Msg, m : Model) : Tea::Cmd
    end

    struct FilteredItem
      property index : Int32
      property item : Item
      property matches : Array(Int32)

      def initialize(@index : Int32, @item : Item, @matches = [] of Int32)
      end
    end

    class FilterMatchesMsg
      include Tea::Msg
      getter matches : Array(FilteredItem)

      def initialize(@matches : Array(FilteredItem))
      end
    end

    struct Rank
      property index : Int32
      property matched_indexes : Array(Int32)

      def initialize(@index : Int32, @matched_indexes : Array(Int32))
      end
    end

    enum FilterState
      Unfiltered
      Filtering
      FilterApplied

      def string : String
        case self
        when Unfiltered
          "unfiltered"
        when Filtering
          "filtering"
        when FilterApplied
          "filter applied"
        end
      end
    end

    Unfiltered    = FilterState::Unfiltered
    Filtering     = FilterState::Filtering
    FilterApplied = FilterState::FilterApplied

    alias FilterFunc = Proc(String, Array(String), Array(Rank))

    class StatusMessageTimeoutMsg
      include Tea::Msg
    end

    class QuitMsg
      include Tea::Msg
    end

    def self.default_filter(term : String, targets : Array(String)) : Array(Rank)
      return [] of Rank if term.empty?

      ranks = [] of Rank
      targets.each_with_index do |target, index|
        if matches = fuzzy_match(term, target)
          ranks << Rank.new(index.to_i32, matches)
        end
      end

      # Sort by match quality (simplified - in Go, fuzzy.Find returns sorted results)
      # For now, we'll sort by match length (more matches = better)
      ranks.sort_by! { |rank| -rank.matched_indexes.size }
      ranks
    end

    def self.unsorted_filter(term : String, targets : Array(String)) : Array(Rank)
      return [] of Rank if term.empty?

      ranks = [] of Rank
      targets.each_with_index do |target, index|
        if matches = fuzzy_match(term, target)
          ranks << Rank.new(index.to_i32, matches)
        end
      end
      # Return unsorted as the name suggests
      ranks
    end

    private def self.fuzzy_match(term : String, target : String) : Array(Int32)?
      # Simple case-insensitive subsequence matching
      # This is a simplified version - Go's fuzzy library does more sophisticated scoring
      term_chars = term.downcase.chars
      target_chars = target.downcase.chars

      matches = [] of Int32
      ti = 0
      target_chars.each_with_index do |char, index|
        break if ti >= term_chars.size
        if char == term_chars[ti]
          matches << index.to_i32
          ti += 1
        end
      end
      return nil unless ti == term_chars.size
      matches
    end

    class Model
      include Bubbles::Help::KeyMap

      property show_title : Bool        # ameba:disable Naming/QueryBoolMethods
      property show_filter : Bool       # ameba:disable Naming/QueryBoolMethods
      property show_status_bar : Bool   # ameba:disable Naming/QueryBoolMethods
      property show_pagination : Bool   # ameba:disable Naming/QueryBoolMethods
      property show_help : Bool         # ameba:disable Naming/QueryBoolMethods
      property filtering_enabled : Bool # ameba:disable Naming/QueryBoolMethods
      property item_name_singular : String
      property item_name_plural : String
      property title : String
      property styles : Styles
      property infinite_scrolling : Bool # ameba:disable Naming/QueryBoolMethods
      property key_map : KeyMap
      property filter : FilterFunc
      property disable_quit_keybindings : Bool # ameba:disable Naming/QueryBoolMethods
      property additional_short_help_keys : Proc(Array(Bubbles::Key::Binding))?
      property additional_full_help_keys : Proc(Array(Bubbles::Key::Binding))?
      property spinner : Bubbles::Spinner::Model
      property show_spinner : Bool # ameba:disable Naming/QueryBoolMethods
      property width : Int32
      property height : Int32
      property paginator : Bubbles::Paginator::Model
      property cursor : Int32
      property help : Bubbles::Help::Model
      property filter_input : Bubbles::TextInput::Model
      property filter_state : FilterState
      property status_message_lifetime : Time::Span
      property status_message : String
      property items : Array(Item)
      property filtered_items : Array(FilteredItem)?
      property delegate : ItemDelegate

      @status_message_expires_at : Time?

      def initialize(@items : Array(Item), @delegate : ItemDelegate, @width : Int32, @height : Int32)
        @show_title = true
        @show_filter = true
        @show_status_bar = true
        @show_pagination = true
        @show_help = true
        @filtering_enabled = true
        @item_name_singular = "item"
        @item_name_plural = "items"
        @title = "List"
        @styles = List.default_styles(true)
        @infinite_scrolling = false
        @key_map = List.default_key_map
        @filter = ->(term : String, targets : Array(String)) { List.default_filter(term, targets) }
        @disable_quit_keybindings = false
        @additional_short_help_keys = nil
        @additional_full_help_keys = nil
        @spinner = Bubbles::Spinner::Model.new
        @spinner.spinner = Bubbles::Spinner::Line
        @spinner.style = @styles.spinner
        @show_spinner = false
        @paginator = Bubbles::Paginator.new
        @paginator.type = Bubbles::Paginator::Type::Dots
        @paginator.active_dot = @styles.active_pagination_dot.string
        @paginator.inactive_dot = @styles.inactive_pagination_dot.string
        @cursor = 0
        @help = Bubbles::Help::Model.new
        @filter_input = Bubbles::TextInput::Model.new
        @filter_input.prompt = "Filter: "
        @filter_input.char_limit = 64
        @filter_input.focus
        @filter_state = FilterState::Unfiltered
        @status_message_lifetime = 1.second
        @status_message = ""
        @status_message_expires_at = nil
        @filtered_items = nil

        update_pagination
        update_keybindings
      end

      def init : Tea::Cmd
        nil
      end

      def set_filtering_enabled(v : Bool) # ameba:disable Naming/AccessorMethodName
        @filtering_enabled = v
        reset_filtering unless v
        update_keybindings
      end

      def set_show_title(v : Bool) # ameba:disable Naming/AccessorMethodName
        @show_title = v
        update_pagination
      end

      def set_filter_text(filter_text : String) # ameba:disable Naming/AccessorMethodName
        @filter_state = FilterState::Filtering
        @filter_input.set_value(filter_text)
        if cmd = filter_items(self)
          if msg = cmd.call
            if fmm = msg.as?(FilterMatchesMsg)
              @filtered_items = fmm.matches
            end
          end
        end
        @filter_state = FilterState::FilterApplied
        go_to_start
        @filter_input.cursor_end
        update_pagination
        update_keybindings
      end

      def set_filter_state(state : FilterState) # ameba:disable Naming/AccessorMethodName
        go_to_start
        @filter_state = state
        @filter_input.cursor_end
        @filter_input.focus
        update_keybindings
      end

      def set_show_filter(v : Bool) # ameba:disable Naming/AccessorMethodName
        @show_filter = v
        update_pagination
      end

      def set_show_status_bar(v : Bool) # ameba:disable Naming/AccessorMethodName
        @show_status_bar = v
        update_pagination
      end

      def set_status_bar_item_name(singular : String, plural : String)
        @item_name_singular = singular
        @item_name_plural = plural
      end

      def status_bar_item_name : {String, String}
        {@item_name_singular, @item_name_plural}
      end

      def set_show_pagination(v : Bool) # ameba:disable Naming/AccessorMethodName
        @show_pagination = v
        update_pagination
      end

      def set_show_help(v : Bool) # ameba:disable Naming/AccessorMethodName
        @show_help = v
        update_pagination
      end

      def set_items(i : Array(Item)) : Tea::Cmd? # ameba:disable Naming/AccessorMethodName
        @items = i
        cmd = nil
        if @filter_state != FilterState::Unfiltered
          @filtered_items = nil
          cmd = filter_items(self)
        end
        update_pagination
        update_keybindings
        cmd
      end

      def set_item(index : Int32, item : Item) : Tea::Cmd
        return nil if index < 0 || index >= @items.size
        @items[index] = item
        cmd = nil
        if @filter_state != FilterState::Unfiltered
          cmd = filter_items(self)
        end
        update_pagination
        cmd
      end

      def insert_item(index : Int32, item : Item) : Tea::Cmd
        @items = insert_item_into_slice(@items, item, index)
        cmd = nil
        if @filter_state != FilterState::Unfiltered
          cmd = filter_items(self)
        end
        update_pagination
        update_keybindings
        cmd
      end

      def remove_item(index : Int32)
        @items = remove_item_from_slice(@items, index)
        if @filter_state != FilterState::Unfiltered
          @filtered_items = remove_filter_match_from_slice(@filtered_items, index)
          reset_filtering if @filtered_items.empty?
        end
        update_pagination
      end

      def set_delegate(d : ItemDelegate) # ameba:disable Naming/AccessorMethodName
        @delegate = d
        update_pagination
      end

      # FilteringEnabled returns whether or not filtering is enabled.
      def filtering_enabled : Bool
        @filtering_enabled
      end

      # ShowTitle returns whether or not the title bar is set to be rendered.
      def show_title : Bool
        @show_title
      end

      # ShowFilter returns whether or not the filter is set to be rendered. Note
      # that this is separate from FilteringEnabled, so filtering can be hidden yet
      # still invoked. This allows you to render filtering differently without
      # having to re-implement it from scratch.
      def show_filter : Bool
        @show_filter
      end

      # ShowStatusBar returns whether or not the status bar is set to be rendered.
      def show_status_bar : Bool
        @show_status_bar
      end

      # ShowPagination returns whether the pagination is visible.
      def show_pagination : Bool
        @show_pagination
      end

      # ShowHelp returns whether or not the help is set to be rendered.
      def show_help : Bool
        @show_help
      end

      # Items returns the items in the list.
      def items : Array(Item)
        @items
      end

      # Cursor returns the index of the cursor on the current page.
      def cursor : Int32
        @cursor
      end

      # FilterState returns the current filter state.
      def filter_state : FilterState
        @filter_state
      end

      # FilterValue returns the current value of the filter.
      def filter_value : String
        @filter_input.value
      end

      # SettingFilter returns whether or not the user is currently editing the
      # filter value. It's purely a convenience method.
      def setting_filter : Bool
        @filter_state == FilterState::Filtering
      end

      # IsFiltered returns whether or not the list is currently filtered.
      # It's purely a convenience method.
      def filtered : Bool
        @filter_state == FilterState::FilterApplied
      end

      # Width returns the current width setting.
      def width : Int32
        @width
      end

      # Height returns the current height setting.
      def height : Int32
        @height
      end

      def select(index : Int32)
        select_item(index)
      end

      def select_item(index : Int32)
        @paginator.page = index // @paginator.per_page
        @cursor = index % @paginator.per_page
      end

      def reset_selected
        self.select(0)
      end

      def reset_filter
        reset_filtering
      end

      def visible_items : Array(Item)
        if @filter_state != FilterState::Unfiltered
          return (@filtered_items || [] of FilteredItem).map(&.item)
        end
        @items
      end

      def selected_item : Item?
        i = index
        items = visible_items
        return nil if i < 0 || items.empty? || i >= items.size
        items[i]
      end

      def matches_for_item(index : Int32) : Array(Int32)?
        return nil if index >= @filtered_items.size
        @filtered_items[index].matches
      end

      def index : Int32
        @paginator.page * @paginator.per_page + @cursor
      end

      def global_index : Int32
        i = index
        return i if i >= @filtered_items.size
        @filtered_items[i].index
      end

      def cursor_up
        @cursor -= 1
        if @cursor < 0 && @paginator.on_first_page?
          if @infinite_scrolling
            go_to_end
            return
          end
          @cursor = 0
          return
        end
        return if @cursor >= 0
        @paginator.prev_page
        @cursor = max_cursor_index
      end

      def cursor_down
        max_idx = max_cursor_index
        @cursor += 1
        return if @cursor <= max_idx

        unless @paginator.on_last_page?
          @paginator.next_page
          @cursor = 0
          return
        end
        @cursor = max(0, max_idx)
        go_to_start if @infinite_scrolling
      end

      def go_to_start
        @paginator.page = 0
        @cursor = 0
      end

      def go_to_end
        @paginator.page = max(0, @paginator.total_pages - 1)
        @cursor = max_cursor_index
      end

      def prev_page
        @paginator.prev_page
        @cursor = clamp(@cursor, 0, max_cursor_index)
      end

      def next_page
        @paginator.next_page
        @cursor = clamp(@cursor, 0, max_cursor_index)
      end

      def filter_value : String
        @filter_input.value
      end

      def setting_filter? : Bool
        @filter_state == FilterState::Filtering
      end

      def setting_filter : Bool
        setting_filter?
      end

      def filtered? : Bool
        @filter_state == FilterState::FilterApplied
      end

      def filtered : Bool
        filtered?
      end

      def set_spinner(spinner_data : Bubbles::Spinner::SpinnerData) # ameba:disable Naming/AccessorMethodName
        @spinner.spinner = spinner_data
      end

      def toggle_spinner : Tea::Cmd
        unless @show_spinner
          return start_spinner
        end
        stop_spinner
        nil
      end

      def start_spinner : Tea::Cmd
        @show_spinner = true
        -> { @spinner.tick.as(Tea::Msg?) }
      end

      def stop_spinner
        @show_spinner = false
      end

      def disable_quit_keybindings
        @disable_quit_keybindings = true
        @key_map.quit.set_enabled(false)
        @key_map.force_quit.set_enabled(false)
      end

      def new_status_message(s : String) : Tea::Cmd
        @status_message = s
        @status_message_expires_at = Time.utc + @status_message_lifetime
        -> {
          sleep(@status_message_lifetime)
          StatusMessageTimeoutMsg.new.as(Tea::Msg?)
        }
      end

      def set_width(v : Int32) # ameba:disable Naming/AccessorMethodName
        set_size(v, @height)
      end

      def set_height(v : Int32) # ameba:disable Naming/AccessorMethodName
        set_size(@width, v)
      end

      def set_size(width : Int32, height : Int32)
        prompt_width = Lipgloss.width(@styles.title.render(@filter_input.prompt))
        @width = width
        @height = height
        @help.set_width(width)
        @filter_input.width = width - prompt_width - Lipgloss.width(spinner_view)
        update_pagination
        update_keybindings
      end

      def update(msg : Tea::Msg) : {self, Tea::Cmd}
        cmds = [] of Tea::Cmd?

        case msg
        when Tea::KeyPressMsg
          if Bubbles::Key.matches?(msg, @key_map.force_quit)
            return {self, -> { QuitMsg.new.as(Tea::Msg?) }}
          end
        when FilterMatchesMsg
          @filtered_items = msg.matches
          return {self, nil}
        when Bubbles::Spinner::TickMsg
          @spinner, cmd = @spinner.update(msg)
          cmds << cmd if @show_spinner
        when StatusMessageTimeoutMsg
          hide_status_message
        end

        if @filter_state == FilterState::Filtering
          cmds << handle_filtering(msg).as(Tea::Cmd?)
        else
          cmds << handle_browsing(msg).as(Tea::Cmd?)
        end

        # Remove nil commands
        cmds.reject!(&.nil?)

        if cmds.empty?
          {self, nil}
        else
          # Convert to tuple for splat
          case cmds.size
          when 1
            {self, cmds[0]}
          when 2
            {self, Tea.batch(cmds[0], cmds[1])}
          else
            # Should not happen, but handle it
            {self, Tea.batch(cmds[0], cmds[1])}
          end
        end
      end

      def short_help : Array(Bubbles::Key::Binding)
        kb = [] of Bubbles::Key::Binding
        kb << @key_map.cursor_up
        kb << @key_map.cursor_down
        filtering = @filter_state == FilterState::Filtering
        if !filtering && (hkm = @delegate.as?(Bubbles::Help::KeyMap))
          kb.concat(hkm.short_help)
        end
        kb << @key_map.filter
        kb << @key_map.clear_filter
        kb << @key_map.accept_while_filtering
        kb << @key_map.cancel_while_filtering
        unless filtering
          if more = @additional_short_help_keys
            kb.concat(more.call)
          end
        end
        kb << @key_map.quit
        kb << @key_map.show_full_help
        kb
      end

      def full_help : Array(Array(Bubbles::Key::Binding))
        kb = [[
          @key_map.cursor_up,
          @key_map.cursor_down,
          @key_map.next_page,
          @key_map.prev_page,
          @key_map.go_to_start,
          @key_map.go_to_end,
        ]]
        filtering = @filter_state == FilterState::Filtering
        if !filtering && (hkm = @delegate.as?(Bubbles::Help::KeyMap))
          kb.concat(hkm.full_help)
        end
        list_level = [
          @key_map.filter,
          @key_map.clear_filter,
          @key_map.accept_while_filtering,
          @key_map.cancel_while_filtering,
        ]
        if !filtering
          if more = @additional_full_help_keys
            list_level.concat(more.call)
          end
        end
        kb << list_level
        kb << [@key_map.quit, @key_map.close_full_help]
        kb
      end

      def view : String
        sections = [] of String
        avail_height = @height

        if @show_title || (@show_filter && @filtering_enabled)
          v = title_view
          sections << v
          avail_height -= Lipgloss.height(v)
        end

        if @show_status_bar
          v = status_view
          sections << v
          avail_height -= Lipgloss.height(v)
        end

        if @show_pagination
          v = pagination_view
          sections << v
          avail_height -= Lipgloss.height(v)
        end

        content = Lipgloss.new_style.height(avail_height).render(populated_view)
        sections << content

        if @show_help
          sections << help_view
        end

        Lipgloss.join_vertical(Lipgloss::Position::Left, sections)
      end

      def status_view : String
        status = ""
        total_items = @items.size
        visible_items = visible_items().size

        item_name = visible_items == 1 ? @item_name_singular : @item_name_plural
        items_display = "#{visible_items} #{item_name}"

        if @filter_state == FilterState::Filtering
          status = visible_items == 0 ? @styles.status_empty.render("Nothing matched") : items_display
        elsif @items.empty?
          status = @styles.status_empty.render("No #{@item_name_plural}")
        else
          if @filter_state == FilterState::FilterApplied
            f = truncate(@filter_input.value.strip, 10, ELLIPSIS)
            status += "“#{f}” "
          end
          status += items_display
        end

        num_filtered = total_items - visible_items
        if num_filtered > 0
          status += @styles.divider_dot.string
          status += @styles.status_bar_filter_count.render("#{num_filtered} filtered")
        end

        @styles.status_bar.render(status)
      end

      private def handle_browsing(msg : Tea::Msg) : Tea::Cmd
        if kmsg = msg.as?(Tea::KeyPressMsg)
          case
          when Bubbles::Key.matches?(kmsg, @key_map.clear_filter)
            reset_filtering
          when Bubbles::Key.matches?(kmsg, @key_map.quit)
            return -> { QuitMsg.new.as(Tea::Msg?) }
          when Bubbles::Key.matches?(kmsg, @key_map.cursor_up)
            cursor_up
          when Bubbles::Key.matches?(kmsg, @key_map.cursor_down)
            cursor_down
          when Bubbles::Key.matches?(kmsg, @key_map.prev_page)
            @paginator.prev_page
          when Bubbles::Key.matches?(kmsg, @key_map.next_page)
            @paginator.next_page
          when Bubbles::Key.matches?(kmsg, @key_map.go_to_start)
            go_to_start
          when Bubbles::Key.matches?(kmsg, @key_map.go_to_end)
            go_to_end
          when Bubbles::Key.matches?(kmsg, @key_map.filter)
            hide_status_message
            if @filter_input.value.empty?
              @filtered_items = items_as_filter_items
            end
            go_to_start
            @filter_state = FilterState::Filtering
            @filter_input.cursor_end
            @filter_input.focus
            update_keybindings
            return -> { Bubbles::Cursor::InitialBlinkMsg.new.as(Tea::Msg?) }
          when Bubbles::Key.matches?(kmsg, @key_map.show_full_help) || Bubbles::Key.matches?(kmsg, @key_map.close_full_help)
            @help.show_all = !@help.show_all
            update_pagination
          end
        end

        cmd = @delegate.update(msg, self)
        @cursor = clamp(@cursor, 0, max_cursor_index)
        cmd
      end

      private def handle_filtering(msg : Tea::Msg) : Tea::Cmd
        cmds = [] of Tea::Cmd?
        if kmsg = msg.as?(Tea::KeyPressMsg)
          case
          when Bubbles::Key.matches?(kmsg, @key_map.cancel_while_filtering)
            reset_filtering
            @key_map.filter.set_enabled(true)
            @key_map.clear_filter.set_enabled(false)
          when Bubbles::Key.matches?(kmsg, @key_map.accept_while_filtering)
            hide_status_message
            unless @items.empty?
              h = visible_items
              if h.empty?
                reset_filtering
              else
                @filter_input.blur
                @filter_state = FilterState::FilterApplied
                update_keybindings
                reset_filtering if @filter_input.value.empty?
              end
            end
          end
        end

        new_filter_input, input_cmd = @filter_input.update(msg)
        filter_changed = @filter_input.value != new_filter_input.value
        @filter_input = new_filter_input
        cmds << input_cmd

        if filter_changed
          if cmd = filter_items(self)
            cmds << cmd
          end
          @key_map.accept_while_filtering.set_enabled(@filter_input.value != "")
        end

        update_pagination
        return nil if cmds.empty?

        # Convert to tuple for splat
        case cmds.size
        when 1
          cmds[0] || -> { nil.as(Tea::Msg?) }
        when 2
          Tea.batch(cmds[0], cmds[1])
        else
          # Should not happen
          -> { nil.as(Tea::Msg?) }
        end
      end

      private def title_view : String
        view = ""
        title_bar_style = @styles.title_bar
        spinner_txt = spinner_view
        spinner_width = Lipgloss.width(spinner_txt)
        spinner_left_gap = " "
        spinner_on_left = title_bar_style.get_padding_left >= spinner_width + Lipgloss.width(spinner_left_gap) && @show_spinner

        if @show_filter && @filter_state == FilterState::Filtering
          view += @filter_input.view
        elsif @show_title
          if @show_spinner && spinner_on_left
            view += spinner_txt + spinner_left_gap
            title_bar_gap = title_bar_style.get_padding_left
            title_bar_style = title_bar_style.padding_left(title_bar_gap - spinner_width - Lipgloss.width(spinner_left_gap))
          end

          view += @styles.title.render(@title)
          if @filter_state != FilterState::Filtering
            view += "  " + @status_message
            view = truncate(view, @width - spinner_width, ELLIPSIS)
          end
        end

        if @show_spinner && !spinner_on_left
          avail_space = @width - Lipgloss.width(@styles.title_bar.render(view))
          if avail_space > spinner_width
            view += " " * (avail_space - spinner_width)
            view += spinner_txt
          end
        end

        return view if view.empty?
        title_bar_style.render(view)
      end

      private def pagination_view : String
        return "" if @paginator.total_pages < 2
        s = @paginator.view
        if Lipgloss.width(s) > @width
          @paginator.type = Bubbles::Paginator::Type::Arabic
          s = @styles.arabic_pagination.render(@paginator.view)
        end
        style = @styles.pagination_style
        if @delegate.spacing == 0 && style.get_margin_top == 0
          style = style.margin_top(1)
        end
        style.render(s)
      end

      private def populated_view : String
        items = visible_items
        return "" if items.empty? && @filter_state == FilterState::Filtering
        return @styles.no_items.render("No #{@item_name_plural}.") if items.empty?

        String.build do |b|
          start_idx, end_idx = @paginator.get_slice_bounds(items.size.to_i32)
          docs = items[start_idx...end_idx]
          docs.each_with_index do |item, i|
            @delegate.render(b, self, (i + start_idx).to_i32, item)
            unless i == docs.size - 1
              b << "\n" * (@delegate.spacing + 1)
            end
          end

          items_on_page = @paginator.items_on_page(items.size.to_i32)
          if items_on_page < @paginator.per_page
            n = (@paginator.per_page - items_on_page) * (@delegate.height + @delegate.spacing)
            n -= @delegate.height - 1 if items.empty?
            b << "\n" * n
          end
        end
      end

      private def help_view : String
        @styles.help_style.render(@help.view(self))
      end

      private def spinner_view : String
        @spinner.view
      end

      private def reset_filtering
        return if @filter_state == FilterState::Unfiltered
        @filter_state = FilterState::Unfiltered
        @filter_input.reset
        @filtered_items = [] of FilteredItem
        update_pagination
        update_keybindings
      end

      private def items_as_filter_items : Array(FilteredItem)
        @items.map_with_index { |item, i| FilteredItem.new(i.to_i32, item) }
      end

      private def update_keybindings
        case @filter_state
        when FilterState::Filtering
          @key_map.cursor_up.set_enabled(false)
          @key_map.cursor_down.set_enabled(false)
          @key_map.next_page.set_enabled(false)
          @key_map.prev_page.set_enabled(false)
          @key_map.go_to_start.set_enabled(false)
          @key_map.go_to_end.set_enabled(false)
          @key_map.filter.set_enabled(false)
          @key_map.clear_filter.set_enabled(false)
          @key_map.cancel_while_filtering.set_enabled(true)
          @key_map.accept_while_filtering.set_enabled(@filter_input.value != "")
          @key_map.quit.set_enabled(false)
          @key_map.show_full_help.set_enabled(false)
          @key_map.close_full_help.set_enabled(false)
        else
          has_items = !@items.empty?
          @key_map.cursor_up.set_enabled(has_items)
          @key_map.cursor_down.set_enabled(has_items)

          has_pages = @paginator.total_pages > 1
          @key_map.next_page.set_enabled(has_pages)
          @key_map.prev_page.set_enabled(has_pages)

          @key_map.go_to_start.set_enabled(has_items)
          @key_map.go_to_end.set_enabled(has_items)

          @key_map.filter.set_enabled(@filtering_enabled && has_items)
          @key_map.clear_filter.set_enabled(@filter_state == FilterState::FilterApplied)
          @key_map.cancel_while_filtering.set_enabled(false)
          @key_map.accept_while_filtering.set_enabled(false)
          @key_map.quit.set_enabled(!@disable_quit_keybindings)

          min_help = List.count_enabled_bindings(full_help) > 1
          @key_map.show_full_help.set_enabled(min_help)
          @key_map.close_full_help.set_enabled(min_help)
        end
      end

      private def update_pagination
        idx = index
        avail_height = @height

        if @show_title || (@show_filter && @filtering_enabled)
          avail_height -= Lipgloss.height(title_view)
        end
        avail_height -= Lipgloss.height(status_view) if @show_status_bar
        avail_height -= Lipgloss.height(pagination_view) if @show_pagination
        avail_height -= Lipgloss.height(help_view) if @show_help

        page_rows = @delegate.height + @delegate.spacing
        page_rows = 1 if page_rows <= 0
        @paginator.per_page = max(1, avail_height // page_rows)

        pages = visible_items.size
        if pages < 1
          @paginator.total_pages = 1
        else
          @paginator.set_total_pages(pages.to_i32)
        end

        @paginator.page = idx // @paginator.per_page
        @cursor = idx % @paginator.per_page

        if @paginator.page >= @paginator.total_pages - 1
          @paginator.page = max(0, @paginator.total_pages - 1)
        end
      end

      private def hide_status_message
        @status_message = ""
        @status_message_expires_at = nil
      end

      private def max_cursor_index : Int32
        max(0, @paginator.items_on_page(visible_items.size.to_i32) - 1)
      end

      private def clamp(v : Int32, low : Int32, high : Int32) : Int32
        l = low
        h = high
        if h < l
          l, h = h, l
        end
        max(l, min(h, v))
      end

      private def min(a : Int32, b : Int32) : Int32
        a < b ? a : b
      end

      private def max(a : Int32, b : Int32) : Int32
        a > b ? a : b
      end

      private def truncate(s : String, width : Int32, tail : String) : String
        return "" if width <= 0
        return s if Lipgloss.width(s) <= width
        tail_width = Lipgloss.width(tail)
        return tail if tail_width >= width
        out = [] of Char
        s.each_char do |char|
          break if Lipgloss.width((out + [char]).join) + tail_width > width
          out << char
        end
        out.join + tail
      end

      private def filter_items(m : Model) : Tea::Cmd
        -> {
          if m.filter_input.value.empty? || m.filter_state == FilterState::Unfiltered
            all_items = m.items.map_with_index { |item, i| FilteredItem.new(i.to_i32, item) }
            FilterMatchesMsg.new(all_items).as(Tea::Msg?)
          else
            targets = m.items.map(&.filter_value)
            matches = [] of FilteredItem
            m.filter.call(m.filter_input.value, targets).each do |rank|
              ri = rank.index
              next if ri < 0 || ri >= m.items.size
              matches << FilteredItem.new(ri, m.items[ri], rank.matched_indexes)
            end
            FilterMatchesMsg.new(matches).as(Tea::Msg?)
          end
        }
      end

      private def insert_item_into_slice(items : Array(Item), item : Item, index : Int32) : Array(Item)
        return [item] of Item if items.empty?
        return items + [item] if index >= items.size

        idx = max(0, index)
        result = items.dup
        result << item
        # Shift elements to make space
        (result.size - 1).downto(idx + 1) do |i|
          result[i] = result[i - 1]
        end
        result[idx] = item
        result
      end

      private def remove_item_from_slice(items : Array(Item), index : Int32) : Array(Item)
        return items if index < 0 || index >= items.size
        result = items.dup
        # Use copy like Go does
        result.copy_from(result.to_unsafe + index + 1, index, result.size - index - 1)
        result.pop
        result
      end

      private def remove_filter_match_from_slice(items : Array(FilteredItem), index : Int32) : Array(FilteredItem)
        return items if index < 0 || index >= items.size
        result = items.dup
        # Use copy like Go does
        result.copy_from(result.to_unsafe + index + 1, index, result.size - index - 1)
        result.pop
        result
      end
    end

    def self.new(items : Array(Item), delegate : ItemDelegate, width : Int32, height : Int32) : Model
      Model.new(items, delegate, width, height)
    end

    def self.count_enabled_bindings(groups : Array(Array(Bubbles::Key::Binding))) : Int32
      agg = 0
      groups.each do |group|
        group.each { |binding| agg += 1 if binding.enabled? }
      end
      agg
    end
  end
end
