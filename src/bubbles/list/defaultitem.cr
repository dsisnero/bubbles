require "lipgloss"
require "../help"
require "../key"
require "./style"

module Bubbles
  module List
    module DefaultItem
      include Item

      abstract def title : String
      abstract def description : String
    end

    struct DefaultItemStyles
      property normal_title : Lipgloss::Style
      property normal_desc : Lipgloss::Style
      property selected_title : Lipgloss::Style
      property selected_desc : Lipgloss::Style
      property dimmed_title : Lipgloss::Style
      property dimmed_desc : Lipgloss::Style
      property filter_match : Lipgloss::Style

      def initialize(
        @normal_title = Lipgloss::Style.new,
        @normal_desc = Lipgloss::Style.new,
        @selected_title = Lipgloss::Style.new,
        @selected_desc = Lipgloss::Style.new,
        @dimmed_title = Lipgloss::Style.new,
        @dimmed_desc = Lipgloss::Style.new,
        @filter_match = Lipgloss::Style.new,
      )
      end
    end

    def self.new_default_item_styles(_is_dark : Bool) : DefaultItemStyles
      light_dark = ->(_light : String, dark : String) { Lipgloss.color(dark) }
      s = DefaultItemStyles.new

      s.normal_title = Lipgloss.new_style.foreground(light_dark.call("#1a1a1a", "#dddddd")).padding(0, 0, 0, 2)
      s.normal_desc = s.normal_title.foreground(light_dark.call("#A49FA5", "#777777"))

      s.selected_title = Lipgloss.new_style
        .border(Lipgloss.normal_border, false, false, false, true)
        .border_foreground(light_dark.call("#F793FF", "#AD58B4"))
        .foreground(light_dark.call("#EE6FF8", "#EE6FF8"))
        .padding(0, 0, 0, 1)
      s.selected_desc = s.selected_title.foreground(light_dark.call("#F793FF", "#AD58B4"))

      s.dimmed_title = Lipgloss.new_style.foreground(light_dark.call("#A49FA5", "#777777")).padding(0, 0, 0, 2)
      s.dimmed_desc = s.dimmed_title.foreground(light_dark.call("#C2B8C2", "#4D4D4D"))
      s.filter_match = Lipgloss.new_style.underline(true)
      s
    end

    class DefaultDelegate
      include ItemDelegate
      include Bubbles::Help::KeyMap

      property show_description : Bool # ameba:disable Naming/QueryBoolMethods
      property styles : DefaultItemStyles
      property update_func : Proc(Tea::Msg, Model, Tea::Cmd)?
      property short_help_func : Proc(Array(Bubbles::Key::Binding))?
      property full_help_func : Proc(Array(Array(Bubbles::Key::Binding)))?
      @height : Int32
      @spacing : Int32

      def initialize
        @show_description = true
        @styles = List.new_default_item_styles(true)
        @update_func = nil
        @short_help_func = nil
        @full_help_func = nil
        @height = 2
        @spacing = 1
      end

      def set_height(i : Int32) # ameba:disable Naming/AccessorMethodName
        @height = i
      end

      def height : Int32
        @show_description ? @height : 1
      end

      def set_spacing(i : Int32) # ameba:disable Naming/AccessorMethodName
        @spacing = i
      end

      def spacing : Int32
        @spacing
      end

      def update(msg : Tea::Msg, m : Model) : Tea::Cmd
        if f = @update_func
          return f.call(msg, m)
        end
        nil
      end

      def render(w : IO, m : Model, index : Int32, item : Item)
        di = item.as?(DefaultItem)
        return unless di
        return if m.width <= 0

        s = @styles
        title = di.title
        desc = di.description
        matched_runes = [] of Int32

        textwidth = m.width - s.normal_title.get_padding_left - s.normal_title.get_padding_right
        title = truncate(title, textwidth, ELLIPSIS)
        if @show_description
          lines = [] of String
          desc.split('\n').each_with_index do |line, i|
            break if i >= @height - 1
            lines << truncate(line, textwidth, ELLIPSIS)
          end
          desc = lines.join("\n")
        end

        selected = index == m.index
        empty_filter = m.filter_state == FilterState::Filtering && m.filter_value == ""
        filtered = m.filter_state == FilterState::Filtering || m.filter_state == FilterState::FilterApplied
        if filtered && index < (m.filtered_items || [] of FilteredItem).size
          if matches = m.matches_for_item(index)
            matched_runes = matches
          end
        end

        if empty_filter
          title = s.dimmed_title.render(title)
          desc = s.dimmed_desc.render(desc)
        elsif selected && m.filter_state != FilterState::Filtering
          if filtered
            unmatched = s.selected_title.inline(true)
            matched = unmatched.inherit(s.filter_match)
            title = Lipgloss.style_runes(title, matched_runes, matched, unmatched)
          end
          title = s.selected_title.render(title)
          desc = s.selected_desc.render(desc)
        else
          if filtered
            unmatched = s.normal_title.inline(true)
            matched = unmatched.inherit(s.filter_match)
            title = Lipgloss.style_runes(title, matched_runes, matched, unmatched)
          end
          title = s.normal_title.render(title)
          desc = s.normal_desc.render(desc)
        end

        if @show_description
          w << "#{title}\n#{desc}"
        else
          w << title
        end
      end

      def short_help : Array(Bubbles::Key::Binding)
        if f = @short_help_func
          return f.call
        end
        [] of Bubbles::Key::Binding
      end

      def full_help : Array(Array(Bubbles::Key::Binding))
        if f = @full_help_func
          return f.call
        end
        [] of Array(Bubbles::Key::Binding)
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
    end

    def self.new_default_delegate : DefaultDelegate
      DefaultDelegate.new
    end
  end
end
