require "./spec_helper"

# Helper: creates a textarea matching Go's newTextArea().
def new_textarea : Bubbles::Textarea::Model
  ta = Bubbles::Textarea.new
  ta.prompt = "> "
  ta.placeholder = "Hello, World!"
  ta.focus
  ta
end

# Helper: creates a dynamic-height textarea matching Go's newDynamicTextArea().
def new_dynamic_textarea(min_h : Int32, max_h : Int32) : Bubbles::Textarea::Model
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

# Helper: send a string of characters through update (matching Go sendString).
def send_string(ta, str : String)
  str.each_char { |ch| ta, _ = ta.update(Tea.key(ch)) }
  ta
end

# Helper: strips ANSI escape codes and trims trailing whitespace per line (matching Go stripString).
def strip_ansi(str : String) : String
  stripped = Ansi.strip(str)
  stripped.lines.reject { |l| l.strip.empty? }.join("\n")
end

# Helper: normalized comparison (strip ANSI + heredoc format)
def normalized_view(str : String) : String
  strip_ansi(str).strip
end

describe Bubbles::Textarea do
  # Go: TestVerticalScrolling
  it "TestVerticalScrolling" do
    textarea = Bubbles::Textarea.new
    textarea.prompt = ""
    textarea.show_line_numbers = false
    textarea.set_height(1)
    textarea.set_width(20)
    textarea.char_limit = 100
    textarea.focus

    input = "This is a really long line that should wrap around the text area."
    input.each_char { |k| textarea, _ = textarea.update(Tea.key(k)) }

    view = textarea.view
    view.should contain("the text area.")

    lines = [
      "This is a really",
      "long line that",
      "should wrap around",
      "the text area.",
    ]
    textarea.viewport.goto_top
    lines.each do |line|
      view = textarea.view
      view.should contain(line)
      textarea.viewport.scroll_down(1)
    end
  end

  # Go: TestWordWrapOverflowing
  it "TestWordWrapOverflowing" do
    textarea = Bubbles::Textarea.new
    textarea.set_height(3)
    textarea.set_width(20)
    textarea.char_limit = 500

    input = "Testing Testing Testing Testing Testing Testing Testing Testing"
    input.each_char { |k| textarea, _ = textarea.update(Tea.key(k)) }

    textarea.row = 0
    textarea.col = 0

    "Testing".each_char { |k| textarea, _ = textarea.update(Tea.key(k)) }

    last_line_width = textarea.line_info.width
    last_line_width.should be <= 20
  end

  # Go: TestValueSoftWrap
  it "TestValueSoftWrap" do
    textarea = Bubbles::Textarea.new
    textarea.set_width(16)
    textarea.set_height(10)
    textarea.char_limit = 500
    textarea.focus

    input = "Testing Testing Testing Testing Testing Testing Testing Testing"
    input.each_char { |k| textarea, _ = textarea.update(Tea.key(k)) }

    value = textarea.value
    value.should eq(input)
  end

  # Go: TestSetValue
  it "TestSetValue" do
    textarea = Bubbles::Textarea.new
    textarea.set_value("Foo\nBar\nBaz")
    textarea.row.should eq(2)
    textarea.col.should eq(3)
    textarea.value.should eq("Foo\nBar\nBaz")

    textarea.set_value("Test")
    textarea.value.should eq("Test")
  end

  # Go: TestInsertString
  it "TestInsertString" do
    textarea = Bubbles::Textarea.new
    textarea.focus
    input = "foo baz"
    input.each_char { |k| textarea, _ = textarea.update(Tea.key(k)) }

    textarea.col = 4
    textarea.insert_string("bar ")

    textarea.value.should eq("foo bar baz")
  end

  # Go: TestCanHandleEmoji
  it "TestCanHandleEmoji" do
    textarea = Bubbles::Textarea.new
    textarea.focus
    input = "🧋"
    input.each_char { |k| textarea, _ = textarea.update(Tea.key(k)) }

    textarea.value.should eq("🧋")

    textarea.set_value("🧋🧋🧋")
    textarea.value.should eq("🧋🧋🧋")
    textarea.col.should eq(3)
    textarea.line_info.char_offset.should eq(6)
  end

  # Go: TestVerticalNavigationKeepsCursorHorizontalPosition
  it "TestVerticalNavigationKeepsCursorHorizontalPosition" do
    textarea = Bubbles::Textarea.new
    textarea.focus
    textarea.set_width(20)
    textarea.set_value("你好你好\nHello")

    textarea.row = 0
    textarea.col = 2

    line_info = textarea.line_info
    line_info.char_offset.should eq(4)
    line_info.column_offset.should eq(2)

    down_msg = Tea.key(Tea::KeyDown)
    textarea, _ = textarea.update(down_msg)

    line_info = textarea.line_info
    line_info.char_offset.should eq(4)
    line_info.column_offset.should eq(4)
  end

  # Go: TestVerticalNavigationShouldRememberPositionWhileTraversing
  it "TestVerticalNavigationShouldRememberPositionWhileTraversing" do
    textarea = Bubbles::Textarea.new
    textarea.focus
    textarea.set_width(40)
    textarea.set_value("Hello\nWorld\nThis is a long line.")

    textarea.col.should eq(20)
    textarea.row.should eq(2)

    up_msg = Tea.key(Tea::KeyUp)
    textarea, _ = textarea.update(up_msg)
    textarea.col.should eq(5)
    textarea.row.should eq(1)

    textarea, _ = textarea.update(up_msg)
    textarea.col.should eq(5)
    textarea.row.should eq(0)

    down_msg = Tea.key(Tea::KeyDown)
    textarea, _ = textarea.update(down_msg)
    textarea, _ = textarea.update(down_msg)
    textarea.col.should eq(20)
    textarea.row.should eq(2)

    textarea, _ = textarea.update(up_msg)
    left_msg = Tea.key(Tea::KeyLeft)
    textarea, _ = textarea.update(left_msg)
    textarea.col.should eq(4)
    textarea.row.should eq(1)

    textarea, _ = textarea.update(down_msg)
    textarea.col.should eq(4)
    textarea.row.should eq(2)
  end

  # Go: TestView (subset: essential layout tests)
  describe "TestView" do
    it "placeholder" do
      ta = new_textarea
      view = normalized_view(ta.view)
      view.should contain("1 Hello, World!")
    end

    it "single line" do
      ta = new_textarea
      ta.set_value("the first line")
      view = normalized_view(ta.view)
      view.should contain("1 the first line")
    end

    it "multiple lines" do
      ta = new_textarea
      ta.set_value("the first line\nthe second line\nthe third line")
      view = normalized_view(ta.view)
      view.should contain("1 the first line")
      view.should contain("2 the second line")
      view.should contain("3 the third line")
    end

    it "single line without line numbers" do
      ta = new_textarea
      ta.set_value("the first line")
      ta.show_line_numbers = false
      view = normalized_view(ta.view)
      view.should contain("the first line")
    end

    it "type single line" do
      ta = new_textarea
      ta = send_string(ta, "foo")
      view = normalized_view(ta.view)
      view.should contain("1 foo")
    end

    it "type multiple lines" do
      ta = new_textarea
      ta = send_string(ta, "foo\nbar\nbaz")
      view = normalized_view(ta.view)
      view.should contain("1 foo")
      view.should contain("2 bar")
      view.should contain("3 baz")
    end

    it "softwrap" do
      ta = new_textarea
      ta.show_line_numbers = false
      ta.prompt = ""
      ta.set_width(5)
      ta = send_string(ta, "foo bar baz")
      view = normalized_view(ta.view)
      view.should contain("foo")
      view.should contain("bar")
      view.should contain("baz")
    end

    it "single line character limit" do
      ta = new_textarea
      ta.char_limit = 7
      ta = send_string(ta, "foo bar baz")
      view = normalized_view(ta.view)
      view.should_not contain("foo bar baz")
    end

    it "set width" do
      ta = new_textarea
      ta.set_width(10)
      ta = send_string(ta, "12")
      view = normalized_view(ta.view)
      view.should contain("1 12")
    end

    it "set width with style" do
      ta = Bubbles::Textarea.new
      s = ta.styles
      s.focused.base = Lipgloss::Style.new.border(Lipgloss.normal_border)
      ta.set_styles(s)
      ta.focus
      ta.set_width(12)
      ta = send_string(ta, "1")
      view = ta.view
      view.should contain("┌")
      view.should contain("└")
    end

    it "single line and custom end of buffer character" do
      ta = new_textarea
      ta.set_value("the first line")
      ta.end_of_buffer_character = '*'
      view = normalized_view(ta.view)
      view.should contain("1 the first line")
      view.should contain("*")
    end

    it "multiple lines and custom end of buffer character" do
      ta = new_textarea
      ta.set_value("the first line\nthe second line\nthe third line")
      ta.end_of_buffer_character = '*'
      view = normalized_view(ta.view)
      view.should contain("1 the first line")
      view.should contain("2 the second line")
      view.should contain("3 the third line")
      view.should contain("*")
    end

    it "placeholder min width" do
      ta = new_textarea
      ta.set_width(0)
      view = normalized_view(ta.view)
      view.should_not be_empty
    end

    it "page up moves to beginning when near top" do
      ta = new_textarea
      ta.show_line_numbers = true
      ta.set_height(4)
      ta.set_width(20)

      lines = (1..10).map { |i| "Line #{i}" }
      ta.set_value(lines.join("\n"))
      ta.row = 3
      ta.col = 0
      ta.viewport.set_y_offset(0)
      ta.page_up
      ta.row.should eq(0)
    end

    it "page down moves to end when near bottom" do
      ta = new_textarea
      ta.set_height(3)
      ta.set_width(20)

      lines = (1..10).map { |i| "Line #{i}" }
      ta.set_value(lines.join("\n"))
      ta.row = 8
      ta.col = 0
      ta.viewport.set_y_offset(7)
      ta.page_down
      ta.row.should eq(9)
    end

    it "placeholder single line" do
      ta = new_textarea
      ta.placeholder = "placeholder the first line"
      ta.show_line_numbers = false
      view = normalized_view(ta.view)
      view.should contain("placeholder the first line")
    end

    it "placeholder multiple lines" do
      ta = new_textarea
      ta.placeholder = "placeholder the first line\nplaceholder the second line\nplaceholder the third line"
      ta.show_line_numbers = false
      view = normalized_view(ta.view)
      view.should contain("placeholder the first line")
      view.should contain("placeholder the second line")
      view.should contain("placeholder the third line")
    end
  end

  # Go: TestWord (with sub-tests)
  describe "TestWord" do
    it "regular input" do
      textarea = Bubbles::Textarea.new
      textarea.focus
      textarea.set_height(3)
      textarea.set_width(20)
      textarea.char_limit = 500

      "Word1 Word2 Word3 Word4".each_char { |k| textarea, _ = textarea.update(Tea.key(k)) }

      textarea.word.should eq("Word4")
    end

    it "navigate" do
      textarea = Bubbles::Textarea.new
      textarea.focus
      textarea.set_height(3)
      textarea.set_width(20)
      textarea.char_limit = 500

      "Word1 Word2 Word3 Word4".each_char { |k| textarea, _ = textarea.update(Tea.key(k)) }

      textarea, _ = textarea.update(Tea.key(Tea::KeyLeft, Tea::ModAlt))
      textarea, _ = textarea.update(Tea.key(Tea::KeyLeft, Tea::ModAlt))
      textarea, _ = textarea.update(Tea.key(Tea::KeyRight))

      textarea.word.should eq("Word3")
    end

    it "delete" do
      textarea = Bubbles::Textarea.new
      textarea.focus
      textarea.set_height(3)
      textarea.set_width(20)
      textarea.char_limit = 500

      "Word1 Word2 Word3 Word4".each_char { |k| textarea, _ = textarea.update(Tea.key(k)) }

      textarea, _ = textarea.update(Tea.key(Tea::KeyEnd))
      textarea, _ = textarea.update(Tea.key(Tea::KeyBackspace, Tea::ModAlt))
      textarea, _ = textarea.update(Tea.key(Tea::KeyBackspace, Tea::ModAlt))
      textarea, _ = textarea.update(Tea.key(Tea::KeyBackspace))

      textarea.word.should eq("Word2")
    end
  end

  # Go: TestDynamicHeight_DefaultUnchanged
  it "TestDynamicHeight_DefaultUnchanged" do
    ta = Bubbles::Textarea.new
    ta.set_height(6)
    ta.set_width(40)

    "hello\nworld\n".each_char do |k|
      ta, _ = ta.update(Tea.key(k))
    end

    ta.height.should eq(6)
  end

  # Go: TestDynamicHeight_GrowsOnNewline
  it "TestDynamicHeight_GrowsOnNewline" do
    ta = new_dynamic_textarea(1, 20)

    ta, _ = ta.update(Tea.key('a'))
    ta.height.should eq(1)

    ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    ta.height.should eq(2)

    ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    ta.height.should eq(3)
  end

  # Go: TestDynamicHeight_GrowsOnSoftWrap
  it "TestDynamicHeight_GrowsOnSoftWrap" do
    ta = new_dynamic_textarea(1, 20)
    input = "abcdefghijklmnopqrstuvwxyz"
    input.each_char { |k| ta, _ = ta.update(Tea.key(k)) }
    ta.height.should be >= 2
  end

  # Go: TestDynamicHeight_ShrinksOnLineDeletion
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

  # Go: TestDynamicHeight_RespectsMinHeight
  it "TestDynamicHeight_RespectsMinHeight" do
    ta = new_dynamic_textarea(5, 20)
    ta, _ = ta.update(Tea.key('a'))
    ta.height.should eq(5)
  end

  # Go: TestDynamicHeight_RespectsMaxHeight
  it "TestDynamicHeight_RespectsMaxHeight" do
    ta = new_dynamic_textarea(1, 5)
    10.times do
      ta, _ = ta.update(Tea.key('x'))
      ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    end
    ta.height.should eq(5)
  end

  # Go: TestDynamicHeight_GrowsOnPaste
  it "TestDynamicHeight_GrowsOnPaste" do
    ta = new_dynamic_textarea(1, 20)
    paste = Tea::PasteMsg.new(content: "line1\nline2\nline3\nline4\nline5")
    ta, _ = ta.update(paste)
    ta.height.should eq(5)
  end

  # Go: TestDynamicHeight_RecalculatesOnSetWidth
  it "TestDynamicHeight_RecalculatesOnSetWidth" do
    ta = new_dynamic_textarea(1, 50)
    ta.set_width(40)
    ta.set_value("abcdefghijklmnopqrstuvwxyz")
    ta.height.should eq(1)

    ta.set_width(10)
    ta.height.should be >= 3
  end

  # Go: TestDynamicHeight_RecalculatesOnSetValue
  it "TestDynamicHeight_RecalculatesOnSetValue" do
    ta = new_dynamic_textarea(1, 20)
    ta.set_value("a\nb\nc\nd\ne")
    ta.height.should eq(5)
  end

  # Go: TestDynamicHeight_CursorPositionAfterGrow
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

  # Go: TestDynamicHeight_CursorPositionAfterShrink
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

  # Go: TestDynamicHeight_CursorPositionAfterPaste
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

  # Go: TestMaxContentHeight_ScrollsBeyondMaxHeight
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

  # Go: TestMaxContentHeight_BlocksAtLimit
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

  # Go: TestMaxContentHeight_BackwardCompat
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

  # Go: TestMaxContentHeight_WithoutDynamicHeight
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

  # Go: TestMaxContentHeight_CursorVisibleWhileScrolling
  it "TestMaxContentHeight_CursorVisibleWhileScrolling" do
    ta = new_dynamic_textarea(1, 5)
    ta.max_content_height = 10

    8.times do
      ta, _ = ta.update(Tea.key('x'))
      ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    end
    ta, _ = ta.update(Tea.key('y'))

    cursor_line = ta.cursor_line_number
    min_visible = ta.viewport.y_offset
    max_visible = min_visible + ta.viewport.height - 1
    cursor_line.should be >= min_visible
    cursor_line.should be <= max_visible
  end

  # Go: TestMaxContentHeight_PasteCapped
  it "TestMaxContentHeight_PasteCapped" do
    ta = Bubbles::Textarea.new
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.max_content_height = 5
    ta.set_width(20)
    ta.focus

    paste = Tea::PasteMsg.new(content: "1\n2\n3\n4\n5\n6\n7\n8\n9\n10")
    ta, _ = ta.update(paste)

    ta.total_visual_lines.should be <= 5
  end

  # Go: TestDynamicHeight_ShrinksWhenScrolledAndLinesDeleted
  it "TestDynamicHeight_ShrinksWhenScrolledAndLinesDeleted" do
    ta = new_dynamic_textarea(1, 5)
    ta.max_content_height = 10

    7.times do
      ta, _ = ta.update(Tea.key('x'))
      ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    end
    ta, _ = ta.update(Tea.key('x'))

    ta.height.should eq(5)
    ta.line_count.should eq(8)

    while ta.line_count > 4
      ta.cursor_end
      while ta.col > 0
        ta, _ = ta.update(Tea.key(Tea::KeyBackspace))
      end
      ta, _ = ta.update(Tea.key(Tea::KeyBackspace))
    end

    ta.height.should eq(4)
    ta.viewport.y_offset.should eq(0)
  end

  # Go: TestDynamicHeight_ShrinksWhenScrolledNoMaxContent
  it "TestDynamicHeight_ShrinksWhenScrolledNoMaxContent" do
    ta = new_dynamic_textarea(1, 99)

    7.times do
      ta, _ = ta.update(Tea.key('x'))
      ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    end
    ta, _ = ta.update(Tea.key('x'))

    ta.height.should eq(8)

    ta.max_height = 5
    ta.set_width(ta.width)

    while ta.line_count > 3
      ta.cursor_end
      while ta.col > 0
        ta, _ = ta.update(Tea.key(Tea::KeyBackspace))
      end
      ta, _ = ta.update(Tea.key(Tea::KeyBackspace))
    end

    ta.height.should eq(3)
    ta.viewport.y_offset.should eq(0)
  end
end
