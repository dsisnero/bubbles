require "lipgloss"
require "../textinput"

module Bubbles
  module List
    BULLET   = "•"
    ELLIPSIS = "…"

    struct Styles
      property title_bar : Lipgloss::Style
      property title : Lipgloss::Style
      property spinner : Lipgloss::Style
      property filter : Bubbles::TextInput::Styles
      property default_filter_character_match : Lipgloss::Style
      property status_bar : Lipgloss::Style
      property status_empty : Lipgloss::Style
      property status_bar_active_filter : Lipgloss::Style
      property status_bar_filter_count : Lipgloss::Style
      property no_items : Lipgloss::Style
      property pagination_style : Lipgloss::Style
      property help_style : Lipgloss::Style
      property active_pagination_dot : Lipgloss::Style
      property inactive_pagination_dot : Lipgloss::Style
      property arabic_pagination : Lipgloss::Style
      property divider_dot : Lipgloss::Style

      def initialize(
        @title_bar = Lipgloss::Style.new,
        @title = Lipgloss::Style.new,
        @spinner = Lipgloss::Style.new,
        @filter = Bubbles::TextInput.default_dark_styles,
        @default_filter_character_match = Lipgloss::Style.new,
        @status_bar = Lipgloss::Style.new,
        @status_empty = Lipgloss::Style.new,
        @status_bar_active_filter = Lipgloss::Style.new,
        @status_bar_filter_count = Lipgloss::Style.new,
        @no_items = Lipgloss::Style.new,
        @pagination_style = Lipgloss::Style.new,
        @help_style = Lipgloss::Style.new,
        @active_pagination_dot = Lipgloss::Style.new,
        @inactive_pagination_dot = Lipgloss::Style.new,
        @arabic_pagination = Lipgloss::Style.new,
        @divider_dot = Lipgloss::Style.new,
      )
      end
    end

    def self.default_styles(dark : Bool) : Styles
      light_dark = ->(light : String, dark_color : String) { dark ? Lipgloss.color(dark_color) : Lipgloss.color(light) }
      very_subdued_color = light_dark.call("#DDDADA", "#3C3C3C")
      subdued_color = light_dark.call("#9B9B9B", "#5C5C5C")

      s = Styles.new
      s.title_bar = Lipgloss.new_style.padding(0, 0, 1, 2)
      s.title = Lipgloss.new_style.background(Lipgloss.color("62")).foreground(Lipgloss.color("230")).padding(0, 1)
      s.spinner = Lipgloss.new_style.foreground(light_dark.call("#8E8E8E", "#747373"))

      prompt = Lipgloss.new_style.foreground(light_dark.call("#04B575", "#ECFD65"))
      s.filter = Bubbles::TextInput.default_styles(dark)
      s.filter.cursor.color = "#EE6FF8"
      s.filter.blurred.prompt = prompt
      s.filter.focused.prompt = prompt

      s.default_filter_character_match = Lipgloss.new_style.underline(true)
      s.status_bar = Lipgloss.new_style.foreground(light_dark.call("#A49FA5", "#777777")).padding(0, 0, 1, 2)
      s.status_empty = Lipgloss.new_style.foreground(subdued_color)
      s.status_bar_active_filter = Lipgloss.new_style.foreground(light_dark.call("#1a1a1a", "#dddddd"))
      s.status_bar_filter_count = Lipgloss.new_style.foreground(very_subdued_color)
      s.no_items = Lipgloss.new_style.foreground(light_dark.call("#909090", "#626262"))
      s.arabic_pagination = Lipgloss.new_style.foreground(subdued_color)
      s.pagination_style = Lipgloss.new_style.padding_left(2)
      s.help_style = Lipgloss.new_style.padding(1, 0, 0, 2)
      s.active_pagination_dot = Lipgloss.new_style.foreground(light_dark.call("#847A85", "#979797")).set_string(BULLET)
      s.inactive_pagination_dot = Lipgloss.new_style.foreground(very_subdued_color).set_string(BULLET)
      s.divider_dot = Lipgloss.new_style.foreground(very_subdued_color).set_string(" #{BULLET} ")
      s
    end
  end
end
