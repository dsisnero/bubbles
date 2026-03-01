require "./spec_helper"
require "../src/bubbles/help"
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
end
