require "bubbletea"
require "lipgloss"
require "./key"

module Bubbles
  module Help
    module KeyMap
      abstract def short_help : Array(Bubbles::Key::Binding)
      abstract def full_help : Array(Array(Bubbles::Key::Binding))
    end

    struct Styles
      property ellipsis : Lipgloss::Style
      property short_key : Lipgloss::Style
      property short_desc : Lipgloss::Style
      property short_separator : Lipgloss::Style
      property full_key : Lipgloss::Style
      property full_desc : Lipgloss::Style
      property full_separator : Lipgloss::Style

      def initialize(
        @ellipsis = Lipgloss::Style.new,
        @short_key = Lipgloss::Style.new,
        @short_desc = Lipgloss::Style.new,
        @short_separator = Lipgloss::Style.new,
        @full_key = Lipgloss::Style.new,
        @full_desc = Lipgloss::Style.new,
        @full_separator = Lipgloss::Style.new,
      )
      end
    end

    def self.default_styles(_is_dark : Bool) : Styles
      Styles.new
    end

    def self.default_dark_styles : Styles
      default_styles(true)
    end

    def self.default_light_styles : Styles
      default_styles(false)
    end

    class Model
      property show_all : Bool # ameba:disable Naming/QueryBoolMethods
      property short_separator : String
      property full_separator : String
      property ellipsis : String
      property styles : Styles
      getter width : Int32

      def initialize
        @show_all = false
        @short_separator = " • "
        @full_separator = "    "
        @ellipsis = "…"
        @styles = Help.default_dark_styles
        @width = 0
      end

      def update(_msg : Tea::Msg?) : {Model, Tea::Cmd}
        {self, nil}
      end

      def view(k : KeyMap) : String
        return full_help_view(k.full_help) if @show_all
        short_help_view(k.short_help)
      end

      def set_width(w : Int32) # ameba:disable Naming/AccessorMethodName
        @width = w
      end

      def width=(w : Int32)
        set_width(w)
      end

      def short_help_view(bindings : Array(Bubbles::Key::Binding)) : String
        return "" if bindings.empty?

        total_width = 0
        separator = @styles.short_separator.inline(true).render(@short_separator)

        String.build do |io|
          bindings.each_with_index do |binding, index|
            next unless binding.enabled

            sep = ""
            if total_width > 0 && index < bindings.size
              sep = separator
            end

            s = sep +
                @styles.short_key.inline(true).render(binding.help.key) + " " +
                @styles.short_desc.inline(true).render(binding.help.desc)
            w = Lipgloss.width(s)

            tail, ok = should_add_item(total_width, w)
            unless ok
              io << tail unless tail.empty?
              break
            end

            total_width += w
            io << s
          end
        end
      end

      def full_help_view(groups : Array(Array(Bubbles::Key::Binding))) : String
        return "" if groups.empty?

        cols = [] of String
        total_width = 0
        separator = @styles.full_separator.inline(true).render(@full_separator)

        groups.each_with_index do |group, i|
          next if group.empty? || !should_render_column(group)

          sep = ""
          if total_width > 0 && i < groups.size
            sep = separator
          end

          keys = [] of String
          descriptions = [] of String
          group.each do |binding|
            next unless binding.enabled
            keys << binding.help.key
            descriptions << binding.help.desc
          end

          col = Lipgloss.join_horizontal(
            Lipgloss::Position::Top,
            sep,
            @styles.full_key.render(keys.join("\n")),
            " ",
            @styles.full_desc.render(descriptions.join("\n"))
          )
          w = Lipgloss.width(col)

          tail, ok = should_add_item(total_width, w)
          unless ok
            cols << tail unless tail.empty?
            break
          end

          total_width += w
          cols << col
        end

        Lipgloss.join_horizontal(Lipgloss::Position::Top, cols)
      end

      private def should_add_item(total_width : Int32, width : Int32) : {String, Bool}
        if @width > 0 && total_width + width > @width
          tail = " " + @styles.ellipsis.inline(true).render(@ellipsis)
          if total_width + Lipgloss.width(tail) < @width
            return {tail, false}
          end
        end
        {"", true}
      end

      private def should_render_column(bindings : Array(Bubbles::Key::Binding)) : Bool
        bindings.any?(&.enabled)
      end
    end
  end
end
