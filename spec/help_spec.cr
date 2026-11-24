require "./spec_helper"
require "ansi"

class TestKeyMap
  include Bubbles::Help::KeyMap

  getter short_help : Array(Bubbles::Key::Binding)
  getter full_help : Array(Array(Bubbles::Key::Binding))

  def initialize
    k = Bubbles::Key.with_keys("x")
    @short_help = [] of Bubbles::Key::Binding
    @full_help = [
      [Bubbles::Key.new_binding(k, Bubbles::Key.with_help("enter", "continue"))],
      [
        Bubbles::Key.new_binding(k, Bubbles::Key.with_help("esc", "back")),
        Bubbles::Key.new_binding(k, Bubbles::Key.with_help("?", "help")),
      ],
      [
        Bubbles::Key.new_binding(k, Bubbles::Key.with_help("H", "home")),
        Bubbles::Key.new_binding(k, Bubbles::Key.with_help("ctrl+c", "quit")),
        Bubbles::Key.new_binding(k, Bubbles::Key.with_help("ctrl+l", "log")),
      ],
    ]
  end
end

describe Bubbles::Help do
  it "TestFullHelp" do
    m = Bubbles::Help::Model.new
    m.full_separator = " | "
    kb = TestKeyMap.new

    [20, 30, 40].each do |w|
      m.set_width(w)
      s = m.full_help_view(kb.full_help)
      s = Ansi.strip(s)

      golden_path = File.expand_path("../vendor/bubbles/help/testdata/TestFullHelp/full_help_#{w}_width.golden", __DIR__)
      expected = File.read(golden_path)
      s.should eq(expected)
    end
  end

  # Go: TestFullHelpStylesColumnPadding
  it "styles the separator padding across full-help columns" do
    m = Bubbles::Help::Model.new
    m.full_separator = " | "
    m.set_width(80)
    styles = m.styles
    styles.full_separator = Lipgloss::Style.new.background(Lipgloss.color("2")).foreground(Lipgloss.color("0"))
    styles.full_key = Lipgloss::Style.new.background(Lipgloss.color("1")).foreground(Lipgloss.color("0"))
    styles.full_desc = Lipgloss::Style.new.background(Lipgloss.color("4")).foreground(Lipgloss.color("0"))
    m.styles = styles

    k = Bubbles::Key.with_keys("x")
    kb = [
      [
        Bubbles::Key.new_binding(k, Bubbles::Key.with_help("a", "alpha")),
        Bubbles::Key.new_binding(k, Bubbles::Key.with_help("b", "beta")),
      ],
      [
        Bubbles::Key.new_binding(k, Bubbles::Key.with_help("c", "gamma")),
        Bubbles::Key.new_binding(k, Bubbles::Key.with_help("d", "delta")),
      ],
    ]

    rendered = m.full_help_view(kb)
    # Lipgloss renders the ANSI green background as truecolor; the point is
    # that the separator style covers the padding spaces on every row.
    rendered.should contain("48;2;0;205;0m   ")
  end

  # Go: TestFullHelpStylesColumnPaddingSkipsDisabledBindings
  it "keeps columns aligned when a binding is disabled" do
    m = Bubbles::Help::Model.new
    m.full_separator = " | "
    m.set_width(80)
    styles = m.styles
    styles.full_separator = Lipgloss::Style.new.background(Lipgloss.color("2")).foreground(Lipgloss.color("0"))
    m.styles = styles

    k = Bubbles::Key.with_keys("x")
    disabled = Bubbles::Key.new_binding(k, Bubbles::Key.with_help("z", "zeta"))
    disabled.set_enabled(false)
    kb = [
      [
        Bubbles::Key.new_binding(k, Bubbles::Key.with_help("a", "alpha")),
        Bubbles::Key.new_binding(k, Bubbles::Key.with_help("b", "beta")),
      ],
      [
        Bubbles::Key.new_binding(k, Bubbles::Key.with_help("c", "gamma")),
        disabled,
        Bubbles::Key.new_binding(k, Bubbles::Key.with_help("d", "delta")),
      ],
    ]

    Ansi.strip(m.full_help_view(kb)).count('\n').should eq(1)
  end

  # Go: TestShortHelpFitsWidth
  it "never exceeds the configured width for short help" do
    k = Bubbles::Key.with_keys("x")
    kb = [
      Bubbles::Key.new_binding(k, Bubbles::Key.with_help("enter", "continue")),
      Bubbles::Key.new_binding(k, Bubbles::Key.with_help("esc", "back")),
      Bubbles::Key.new_binding(k, Bubbles::Key.with_help("ctrl+c", "quit")),
    ]

    m = Bubbles::Help::Model.new
    full = Ansi.string_width(m.short_help_view(kb))
    (1..full).each do |w|
      m.set_width(w)
      Ansi.string_width(m.short_help_view(kb)).should be <= w
    end
  end
end
