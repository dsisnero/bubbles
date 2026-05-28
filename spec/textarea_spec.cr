require "./spec_helper"

# Helper: creates a dynamic-height textarea matching Go newDynamicTextArea.
def new_dynamic_textarea(min_h : Int32, max_h : Int32)
  ta = Bubbles::Textarea.new
  ta.prompt = ""
  ta.show_line_numbers = false
  ta.dynamic_height = true
  ta.min_height = min_h
  ta.max_height = max_h
  ta.set_width(20)
  ta.focus
  ta
end

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
    # Go parity: emoji occupy width 2, so 3 emoji => char offset 6.
    textarea.line_info.char_offset.should eq(6)
  end

  it "TestValueSoftWrap" do
    textarea = Bubbles::Textarea.new
    input = "Testing Testing Testing Testing"
    textarea.insert_string(input)
    textarea.value.should eq(input)
  end

  it "TestVerticalScrolling" do
    textarea = Bubbles::Textarea.new
    textarea.prompt = ""
    textarea.show_line_numbers = false
    textarea.char_limit = 100
    textarea.set_height(1)
    textarea.set_width(20)
    textarea.insert_string("This is a really long line that should wrap around the text area.")
    textarea.view.should contain("This is a ")
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
    rendered = Ansi.strip(textarea.view)
    rendered.should contain("1 a")
    rendered.should contain("2 b")
  end

  it "handles focus/update virtual cursor path without raising" do
    textarea = Bubbles::Textarea.new
    textarea.focus

    textarea.set_value("hi")
    model, _cmd = textarea.update(Tea::WindowSizeMsg.new(80, 24))
    model.value.should eq("hi")

    model, _cmd = textarea.update(Tea.key('!'))
    model.value.should eq("hi!")
  end

  it "TestDynamicHeight_DefaultUnchanged" do
    ta = Bubbles::Textarea.new
    ta.set_height(6)
    ta.set_width(40)

    "hello\nworld\n".each_char do |k|
      ta, _ = ta.update(Tea.key(k))
    end

    ta.height.should eq(6)
  end

  it "TestDynamicHeight_GrowsOnNewline" do
    ta = new_dynamic_textarea(1, 20)

    ta, _ = ta.update(Tea.key('a'))
    ta.height.should eq(1)

    ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    ta.height.should eq(2)

    ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    ta.height.should eq(3)
  end

  it "TestDynamicHeight_GrowsOnSoftWrap" do
    ta = new_dynamic_textarea(1, 20)
    input = "abcdefghijklmnopqrstuvwxyz"
    input.each_char { |k| ta, _ = ta.update(Tea.key(k)) }
    ta.height.should be >= 2
  end

  it "TestDynamicHeight_ShrinksOnLineDeletion" do
    ta = new_dynamic_textarea(1, 20)

    ta, _ = ta.update(Tea.key('a'))
    ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    ta, _ = ta.update(Tea.key('b'))
    ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    ta, _ = ta.update(Tea.key('c'))

    ta.height.should eq(3)

    ta.cursor_start
    ta, _ = ta.update(Tea.key(Tea::KeyBackspace))
    ta.height.should eq(2)
  end

  it "TestDynamicHeight_RespectsMinHeight" do
    ta = new_dynamic_textarea(5, 20)
    ta, _ = ta.update(Tea.key('a'))
    ta.height.should eq(5)
  end

  it "TestDynamicHeight_RespectsMaxHeight" do
    ta = new_dynamic_textarea(1, 5)
    10.times do
      ta, _ = ta.update(Tea.key('x'))
      ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    end
    ta.height.should eq(5)
  end

  it "TestDynamicHeight_GrowsOnPaste" do
    ta = new_dynamic_textarea(1, 20)
    paste = Tea::PasteMsg.new(content: "line1\nline2\nline3\nline4\nline5")
    ta, _ = ta.update(paste)
    ta.height.should eq(5)
  end

  it "TestDynamicHeight_RecalculatesOnSetWidth" do
    ta = new_dynamic_textarea(1, 50)
    ta.set_width(40)
    ta.set_value("abcdefghijklmnopqrstuvwxyz")
    ta.height.should eq(1)

    ta.set_width(10)
    ta.height.should be >= 3
  end

  it "TestDynamicHeight_RecalculatesOnSetValue" do
    ta = new_dynamic_textarea(1, 20)
    ta.set_value("a\nb\nc\nd\ne")
    ta.height.should eq(5)
  end

  it "TestDynamicHeight_CursorPositionAfterGrow" do
    ta = new_dynamic_textarea(1, 20)

    5.times do |i|
      ta, _ = ta.update(Tea.key(('a'.ord + i).chr))
      ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    end
    ta, _ = ta.update(Tea.key('f'))

    ta.line.should eq(5)

    cursor_line = ta.cursor_line_number
    min_visible = ta.viewport.y_offset
    max_visible = min_visible + ta.viewport.height - 1
    cursor_line.should be >= min_visible
    cursor_line.should be <= max_visible
  end

  it "TestDynamicHeight_CursorPositionAfterShrink" do
    ta = new_dynamic_textarea(1, 20)

    5.times do |i|
      ta, _ = ta.update(Tea.key(('a'.ord + i).chr))
      ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    end
    ta, _ = ta.update(Tea.key('f'))
    ta.height.should eq(6)

    ta, _ = ta.update(Tea.key(Tea::KeyBackspace))
    ta, _ = ta.update(Tea.key(Tea::KeyBackspace))
    ta, _ = ta.update(Tea.key(Tea::KeyBackspace))
    ta, _ = ta.update(Tea.key(Tea::KeyBackspace))

    cursor_line = ta.cursor_line_number
    min_visible = ta.viewport.y_offset
    max_visible = min_visible + ta.viewport.height - 1
    cursor_line.should be >= min_visible
    cursor_line.should be <= max_visible
  end

  it "TestDynamicHeight_CursorPositionAfterPaste" do
    ta = new_dynamic_textarea(1, 20)
    paste = Tea::PasteMsg.new(content: "line1\nline2\nline3\nline4\nline5")
    ta, _ = ta.update(paste)

    ta.line.should eq(4)

    cursor_line = ta.cursor_line_number
    min_visible = ta.viewport.y_offset
    max_visible = min_visible + ta.viewport.height - 1
    cursor_line.should be >= min_visible
    cursor_line.should be <= max_visible
  end

  it "TestMaxContentHeight_ScrollsBeyondMaxHeight" do
    ta = new_dynamic_textarea(1, 5)
    ta.max_content_height = 10

    8.times do
      ta, _ = ta.update(Tea.key('x'))
      ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    end

    ta.height.should eq(5)
    ta.line_count.should eq(9)
  end

  it "TestMaxContentHeight_BlocksAtLimit" do
    ta = Bubbles::Textarea.new
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.max_content_height = 5
    ta.set_width(20)
    ta.focus

    10.times do
      ta, _ = ta.update(Tea.key('x'))
      ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    end

    ta.total_visual_lines.should be <= 5
  end

  it "TestMaxContentHeight_BackwardCompat" do
    ta = Bubbles::Textarea.new
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.max_height = 10
    ta.set_width(20)
    ta.focus

    15.times do
      ta, _ = ta.update(Tea.key('x'))
      ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    end

    ta.line_count.should be <= 10
  end

  it "TestMaxContentHeight_WithoutDynamicHeight" do
    ta = Bubbles::Textarea.new
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.max_content_height = 5
    ta.set_height(3)
    ta.set_width(20)
    ta.focus

    10.times do
      ta, _ = ta.update(Tea.key('x'))
      ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    end

    ta.height.should eq(3)
  end
end
