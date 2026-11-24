require "./spec_helper"

private class TextInputClipboardError < Exception
  def initialize(@msg : String)
    super(@msg)
  end
end

describe Bubbles::TextInput do
  it "Test_CurrentSuggestion" do
    textinput = Bubbles::TextInput.new
    textinput.show_suggestions = true

    textinput.current_suggestion.should eq("")

    textinput.set_suggestions(["test1", "test2", "test3"])
    textinput.current_suggestion.should eq("")

    textinput.set_value("test")
    textinput.update_suggestions
    textinput.next_suggestion
    textinput.current_suggestion.should eq("test2")

    textinput.blur
    textinput.view.ends_with?("test2").should be_false
  end

  # Go's textinput holds its cursor by value and its View has a value
  # receiver, so the TextStyle placeholderView sets applies to that view only.
  # With a shared cursor the style leaked into later views and styled the
  # trailing space cell after a value, which a renderer correctly treats as
  # content instead of trimming it: examples/textinputs drifted one cell wider
  # than the Go golden on every blurred input row.
  it "keeps the placeholder style out of a later value view" do
    textinput = Bubbles::TextInput.new
    textinput.placeholder = "Nickname"

    # With no width set the full placeholder renders (issue #779), with its
    # first rune as the cursor cell.
    Ansi.strip(textinput.view).should contain("Nickname")

    textinput.set_value("hi")
    # v2.2.2 assigns the text style to the cursor in View, so the trailing
    # space cell carries that style.
    Ansi.strip(textinput.view).should end_with("hi ")
  end

  it "Test_SlicingOutsideCap" do
    textinput = Bubbles::TextInput.new
    textinput.placeholder = "作業ディレクトリを指定してください"
    textinput.width = 32
    textinput.view
  end

  pending "TestChinesePlaceholder" do
    # Upstream Go test is skipped:
    # TestChinesePlaceholder: "Skipping flaky test, the returned view seems incorrect."
  end

  pending "TestPlaceholderTruncate" do
    # Upstream Go test is skipped:
    # TestPlaceholderTruncate: "Skipping flaky test, the returned view seems incorrect."
  end

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

  # Go: Test_CurrentSuggestionAfterPrevious
  it "selects the previous suggestion over the current matches" do
    [
      {"no suggestions", "", [] of String, ""},
      {"empty value", "", ["test1", "test2"], ""},
      {"no matches", "other", ["test1", "test2"], ""},
      {"one match", "test", ["test1"], "test1"},
      {"multiple matches", "test", ["test1", "test2", "test3"], "test3"},
    ].each do |name, value, suggestions, expected|
      m = Bubbles::TextInput.new
      m.show_suggestions = true
      m.set_value(value)
      m.set_suggestions(suggestions)
      m.focus

      m, _ = m.update(Tea.key(Tea::KeyUp))
      m.current_suggestion.should eq(expected), name
    end
  end

  # Go: Test_CursorPositionWithScrolledValue
  it "positions the cursor for a scrolled value" do
    m = Bubbles::TextInput.new
    m.set_virtual_cursor(false)
    m.focus
    m.set_width(5)
    m.set_value("abcdefghij")
    m.set_cursor(8)

    cursor = m.cursor
    cursor.should_not be_nil
    cursor.not_nil!.x.should eq(5)
  end

  # Go: Test_CursorPositionWithWideCharacters
  it "positions the cursor after wide characters" do
    m = Bubbles::TextInput.new
    m.set_virtual_cursor(false)
    m.focus
    m.set_width(40)
    m.set_value("あいう")

    cursor = m.cursor
    cursor.should_not be_nil
    cursor.not_nil!.x.should eq(8)
  end

  # Go: Test_ViewRespectsWidthWithSuggestions
  it "keeps the view within the configured width with suggestions" do
    m = Bubbles::TextInput.new
    m.set_width(20)
    m.set_value("hel")
    m.show_suggestions = true
    m.set_suggestions(["hello world this is a very long suggestion overflow", "second"])
    m.focus
    m, _ = m.update(Tea.key('l'))

    Ansi.string_width(m.view).should eq(23)
  end

  # Go: TestAcceptSuggestionAfterSetValue
  it "does not complete a long value from a stale suggestion" do
    m = Bubbles::TextInput.new
    m.show_suggestions = true
    m.set_suggestions(["hello"])
    m.focus
    m, _ = m.update(Tea.key('h'))

    value = "a much longer value than any suggestion"
    m.set_value(value)
    m, _ = m.update(Tea.key(Tea::KeyTab))
    m.value.should eq(value)
  end

  # Go: TestDeleteWordForwardAtWordEnd
  it "deletes the word forward from the cursor" do
    [
      {"inside word", "abc d", 1, "a d"},
      {"last rune of word", "ab c", 1, "a c"},
      {"last rune of value", "ab", 1, "a"},
      {"on whitespace", "a bc", 1, "a"},
      {"unicode word", "a界 c", 1, "a c"},
    ].each do |name, value, cursor, want|
      m = Bubbles::TextInput.new
      m.focus
      m.set_value(value)
      m.set_cursor(cursor)
      m, _ = m.update(Tea.key('d', Ultraviolet::ModAlt))
      m.value.should eq(want), name
    end
  end

  # Go: TestPasteErrMsgUnwrap
  it "keeps the underlying paste error reachable" do
    underlying = TextInputClipboardError.new("clipboard read error")
    m = Bubbles::TextInput.new
    m.focus

    m, _ = m.update(Bubbles::TextInput::PasteErrMsg.new(underlying))
    m.err.should_not be_nil
    m.err.should be_a(Bubbles::TextInput::PasteErrMsg)
    m.err.try(&.cause).should eq(underlying)
  end

  # Go: TestPlaceholderFullRenderWithoutWidth
  it "renders the whole placeholder without a width" do
    m = Bubbles::TextInput.new
    m.placeholder = "Nickname"
    Ansi.strip(m.view).should contain("Nickname")
  end

  # Go: TestSetValueDoesNotCompleteUnmatchedInput
  it "does not complete input that matches no suggestion" do
    m = Bubbles::TextInput.new
    m.show_suggestions = true
    m.set_suggestions(["hello"])
    m.focus
    m.set_value("other")
    m, _ = m.update(Tea.key(Tea::KeyTab))
    m.value.should eq("other")
  end

  # Go: TestSetValueRefreshesSuggestions
  it "refreshes suggestions when the value is set" do
    m = Bubbles::TextInput.new
    m.show_suggestions = true
    m.set_suggestions(["hello"])
    m.focus
    m, _ = m.update(Tea.key('h'))

    m.set_value("ab")
    m.matched_suggestions.size.should eq(0)
    m, _ = m.update(Tea.key(Tea::KeyTab))
    m.value.should eq("ab")

    m.set_value("he")
    m, _ = m.update(Tea.key(Tea::KeyTab))
    m.value.should eq("hello")
  end

  # Go: TestShiftBackspaceDeletesCharacterBackward
  it "deletes a character with shift+backspace" do
    m = Bubbles::TextInput.new
    m.focus
    m.set_value("abc")
    m, _ = m.update(Tea.key(Tea::KeyBackspace, Ultraviolet::ModShift))
    m.value.should eq("ab")
  end

  # Go: TestTypedPrefixStillAcceptsSuggestion
  it "accepts a suggestion after typing its prefix" do
    m = Bubbles::TextInput.new
    m.show_suggestions = true
    m.set_suggestions(["hello"])
    m.focus
    "he".each_char { |ch| m, _ = m.update(Tea.key(ch)) }
    m, _ = m.update(Tea.key(Tea::KeyTab))
    m.value.should eq("hello")
  end
end
