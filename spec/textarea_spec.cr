require "./spec_helper"
require "../src/bubbles/textarea"

describe Bubbles::Textarea do
  it "TestSetValue" do
    textarea = Bubbles::Textarea.new
    textarea.set_value("Foo\nBar\nBaz")
    textarea.row.should eq(2)
    textarea.col.should eq(3)
    textarea.value.should eq("Foo\nBar\nBaz")

    textarea.set_value("Test")
    textarea.value.should eq("Test")
  end

  it "TestInsertString" do
    textarea = Bubbles::Textarea.new
    textarea.insert_string("foo baz")
    textarea.col = 4
    textarea.insert_string("bar ")
    textarea.value.should eq("foo bar baz")
  end

  it "TestCanHandleEmoji" do
    textarea = Bubbles::Textarea.new
    textarea.insert_string("🧋")
    textarea.value.should eq("🧋")

    textarea.set_value("🧋🧋🧋")
    textarea.value.should eq("🧋🧋🧋")
    textarea.col.should eq(3)
    textarea.line_info.char_offset.should eq(3)
  end

  it "TestValueSoftWrap" do
    textarea = Bubbles::Textarea.new
    input = "Testing Testing Testing Testing"
    textarea.insert_string(input)
    textarea.value.should eq(input)
  end

  it "TestVerticalScrolling" do
    textarea = Bubbles::Textarea.new
    textarea.set_height(1)
    textarea.set_width(20)
    textarea.insert_string("This is a really long line that should wrap around the text area.")
    textarea.view.should contain("text area.")
  end

  it "TestWordWrapOverflowing" do
    textarea = Bubbles::Textarea.new
    textarea.set_height(3)
    textarea.set_width(20)
    textarea.insert_string("Testing Testing Testing Testing Testing")
    textarea.row = 0
    textarea.col = 0
    textarea.insert_string("Testing")
    textarea.value.should contain("Testing")
  end

  it "TestVerticalNavigationKeepsCursorHorizontalPosition" do
    textarea = Bubbles::Textarea.new
    textarea.set_value("你好你好\nHello")
    textarea.row = 0
    textarea.col = 2
    textarea.cursor_down
    textarea.col.should be <= textarea.value.split('\n')[textarea.row].size
  end

  it "TestVerticalNavigationShouldRememberPositionWhileTraversing" do
    textarea = Bubbles::Textarea.new
    textarea.set_value("Hello\nWorld\nThis is a long line.")
    textarea.row = 2
    textarea.col = 4
    textarea.cursor_up
    textarea.cursor_up
    textarea.cursor_down
    textarea.row.should eq(1)
  end

  it "TestWord" do
    textarea = Bubbles::Textarea.new
    textarea.set_value("hello world")
    textarea.set_cursor_column(8)
    textarea.word.should eq("world")
  end

  it "TestView" do
    textarea = Bubbles::Textarea.new
    textarea.set_value("a\nb")
    textarea.view.should eq("a\nb")
  end
end
