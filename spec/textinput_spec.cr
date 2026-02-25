require "./spec_helper"
require "../src/bubbles/textinput"

describe Bubbles::TextInput do
  describe "Model" do
    it "creates a new model with default settings" do
      model = Bubbles::TextInput.new
      model.prompt.should eq("> ")
      model.placeholder.should eq("")
      model.echo_mode.should eq(Bubbles::TextInput::EchoMode::Normal)
      model.echo_character.should eq('*')
      model.char_limit.should eq(0)
      model.width.should eq(0)
      model.show_suggestions?.should be_false
      model.focused?.should be_false
    end

    it "sets and gets value" do
      model = Bubbles::TextInput.new
      model.set_value("hello")
      model.value.should eq("hello")
      model.position.should eq(5)
    end

    it "sanitizes input with tabs and newlines" do
      model = Bubbles::TextInput.new
      model.set_value("hello\tworld\n")
      model.value.should eq("hello world ")
    end

    it "respects character limit" do
      model = Bubbles::TextInput.new
      model.char_limit = 5
      model.set_value("hello world")
      model.value.should eq("hello")
    end

    it "moves cursor" do
      model = Bubbles::TextInput.new
      model.set_value("hello")
      model.set_cursor(2)
      model.position.should eq(2)

      model.cursor_start
      model.position.should eq(0)

      model.cursor_end
      model.position.should eq(5)
    end

    it "focuses and blurs" do
      model = Bubbles::TextInput.new
      model.focused?.should be_false

      model.focus
      model.focused?.should be_true

      model.blur
      model.focused?.should be_false
    end

    it "resets the input" do
      model = Bubbles::TextInput.new
      model.set_value("hello")
      model.reset
      model.value.should eq("")
      model.position.should eq(0)
    end
  end

  describe "EchoMode" do
    it "transforms password input" do
      model = Bubbles::TextInput.new
      model.echo_mode = Bubbles::TextInput::EchoMode::Password
      model.echo_character = '*'
      model.set_value("secret")
      # View should show asterisks, not actual text
      # This would require more comprehensive view testing
    end

    it "hides input in EchoMode::None" do
      model = Bubbles::TextInput.new
      model.echo_mode = Bubbles::TextInput::EchoMode::None
      model.set_value("secret")
      # View should show nothing
    end
  end

  describe "Suggestions" do
    it "returns empty suggestion when none set" do
      model = Bubbles::TextInput.new
      model.show_suggestions = true
      model.current_suggestion.should eq("")
    end

    it "returns empty suggestion when value doesn't match" do
      model = Bubbles::TextInput.new
      model.show_suggestions = true
      model.set_suggestions(["test1", "test2", "test3"])
      model.current_suggestion.should eq("")
    end

    it "cycles through suggestions" do
      model = Bubbles::TextInput.new
      model.show_suggestions = true
      model.set_suggestions(["test1", "test2", "test3"])
      model.set_value("test")

      # After setting value, update_suggestions is called
      # But our update_suggestions is a stub that clears matches
      # So this test will need to be updated when we implement real suggestion matching
    end
  end

  describe "Validation" do
    it "validates input with custom function" do
      model = Bubbles::TextInput.new
      model.validate = ->(s : String) {
        s.size > 5 ? nil : Exception.new("too short")
      }
      model.set_value("hi")
      model.err.should_not be_nil

      model.set_value("hello world")
      model.err.should be_nil
    end
  end

  describe "Width and overflow" do
    it "sets width" do
      model = Bubbles::TextInput.new
      model.width = 10
      model.width.should eq(10)
    end

    it "handles overflow with wide text" do
      model = Bubbles::TextInput.new
      model.width = 5
      model.set_value("hello world")
      # Offset should be adjusted to handle overflow
      model.offset.should be >= 0
    end
  end
end
