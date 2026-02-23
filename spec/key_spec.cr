require "./spec_helper"
require "../src/bubbles/key"

describe Bubbles::Key do
  describe "Binding" do
    it "tests binding enabled" do
      binding = Bubbles::Key.new_binding(
        Bubbles::Key.with_keys("k", "up"),
        Bubbles::Key.with_help("↑/k", "move up"),
      )
      binding.enabled?.should be_true

      binding.set_enabled(false)
      binding.enabled?.should be_false

      binding.set_enabled(true)
      binding.unbind
      binding.enabled?.should be_false
    end

    it "creates binding with keys" do
      binding = Bubbles::Key.new_binding(
        Bubbles::Key.with_keys("a", "b", "c")
      )
      binding.keys.should eq(["a", "b", "c"])
      binding.enabled?.should be_true
    end

    it "creates binding with help" do
      binding = Bubbles::Key.new_binding(
        Bubbles::Key.with_help("ctrl+c", "quit")
      )
      binding.help.key.should eq("ctrl+c")
      binding.help.desc.should eq("quit")
    end

    it "creates disabled binding" do
      binding = Bubbles::Key.new_binding(
        Bubbles::Key.with_disabled
      )
      binding.enabled?.should be_false
    end

    it "sets keys" do
      binding = Bubbles::Key::Binding.new
      binding.set_keys("x", "y", "z")
      binding.keys.should eq(["x", "y", "z"])
    end

    it "sets help" do
      binding = Bubbles::Key::Binding.new
      binding.set_help("enter", "submit")
      binding.help.key.should eq("enter")
      binding.help.desc.should eq("submit")
    end

    it "matches key against bindings" do
      binding1 = Bubbles::Key.new_binding(
        Bubbles::Key.with_keys("k", "up")
      )
      binding2 = Bubbles::Key.new_binding(
        Bubbles::Key.with_keys("j", "down")
      )
      Bubbles::Key.matches?("k", binding1, binding2).should be_true
      Bubbles::Key.matches?("up", binding1, binding2).should be_true
      Bubbles::Key.matches?("j", binding1, binding2).should be_true
      Bubbles::Key.matches?("down", binding1, binding2).should be_true
      Bubbles::Key.matches?("x", binding1, binding2).should be_false
    end

    it "does not match disabled binding" do
      binding = Bubbles::Key.new_binding(
        Bubbles::Key.with_keys("k"),
        Bubbles::Key.with_disabled
      )
      Bubbles::Key.matches?("k", binding).should be_false
    end

    it "does not match unbound binding" do
      binding = Bubbles::Key::Binding.new
      binding.unbind
      Bubbles::Key.matches?("any", binding).should be_false
    end
  end
end
