require "./spec_helper"

# Helpers for the v2.2.2 textarea selection/grapheme parity specs.

private def v222_textarea : Bubbles::Textarea::Model
  ta = Bubbles::Textarea.new
  ta.prompt = "> "
  ta.placeholder = "Hello, World!"
  ta.focus
  ta.view
  ta
end

private def v222_selection_textarea(value : String) : Bubbles::Textarea::Model
  ta = Bubbles::Textarea.new
  ta.prompt = ""
  ta.show_line_numbers = false
  ta.set_width(20)
  ta.set_height(6)
  ta.focus
  ta.set_value(value)
  ta
end

private def v222_send(ta, str : String)
  str.each_char { |ch| ta, _ = ta.update(Tea.key(ch)) }
  ta
end

private def shift_key(code : Int32)
  Tea.key(code, Ultraviolet::ModShift)
end

class V222ClipboardError < Exception
  def initialize(@msg : String)
    super(@msg)
  end
end

describe Bubbles::Textarea do
  # Go: grapheme_test.go / grapheme_cursor_test.go

  it "TestThaiGraphemeNavigationAndDeletion" do
    ["นำ", "น้ำ"].each do |value|
      m = v222_textarea
      m.set_value(value)
      m.line_info.char_offset.should eq(2)

      m, _ = m.update(Tea.key(Tea::KeyLeft))
      m.col.should eq(0)

      m.set_value(value)
      m.cursor_start
      m, _ = m.update(Tea.key(Tea::KeyRight))
      m.col.should eq(value.chars.size)

      m.set_value(value)
      m.cursor_start
      m, _ = m.update(Tea.key(Tea::KeyDelete))
      m.value.should eq("")

      m.set_value(value)
      m, _ = m.update(Tea.key(Tea::KeyBackspace))
      m.value.should eq(value.chars[0...-1].join)
    end
  end

  it "TestGraphemeNavigationKeepsASCIIStepsAndSkipsEmojiCluster" do
    m = v222_textarea
    m.set_value("ab")
    m, _ = m.update(Tea.key(Tea::KeyLeft))
    m.col.should eq(1)

    value = "A👩‍💻B"
    m.set_value(value)
    m, _ = m.update(Tea.key(Tea::KeyLeft))
    m.col.should eq(value.chars.size - 1)
    m, _ = m.update(Tea.key(Tea::KeyLeft))
    m.col.should eq(1)
  end

  it "TestSetCursorColumnSnapsToGraphemeStart" do
    m = v222_textarea
    m.set_value("A👩‍💻B")
    m.set_cursor_column(2)
    m.col.should eq(1)
  end

  it "TestVerticalCursorSnapsToGraphemeStart" do
    m = v222_textarea
    m.set_value("ab\n👩‍💻x")
    m.set_cursor_column(0)
    m.cursor_up
    m.set_cursor_column(1)
    m.cursor_down
    line = m.value.split('\n')[m.row].chars
    start, _ = Bubbles::Textarea.grapheme_at(line, m.col)
    start.should eq(m.col)
  end

  it "TestBackspaceRemovesMarkWithoutConsonant" do
    ["น้", "कि"].each do |value|
      m = v222_textarea
      m.set_value(value)
      m, _ = m.update(Tea.key(Tea::KeyBackspace))
      m.value.should eq(value.chars[0...-1].join)
    end
  end

  it "TestWordOperationsAdvanceOverGraphemes" do
    ["नमस्ते rest", "น้ำ rest", "👩‍💻 rest", "e\u0301 rest"].each do |value|
      m = v222_textarea
      m.set_value(value)
      m.cursor_start
      m.word_right
      m.col.should_not eq(0)
      start, _ = Bubbles::Textarea.grapheme_at(m.value.chars, m.col)
      start.should eq(m.col)

      m.cursor_start
      m.delete_word_right
      m.value.should eq(" rest")
    end
  end

  it "TestBackspaceRemovesEmojiSequenceWhole" do
    {
      "x👍🏽"                                                      => "x",
      "x👨‍👩‍👧"                                                   => "x",
      "x🇺🇸"                                                      => "x",
      "x❤\ufe0f"                                                 => "x",
      "x1\ufe0f\u20e3"                                           => "x",
      "x🏴\u{E0067}\u{E0062}\u{E0073}\u{E0063}\u{E0074}\u{E007F}" => "x",
      "x👨\u200d"                                                 => "x👨",
      "क्\u200d"                                                 => "क्",
      "x🧑\u200d🎄"                                                => "x",
      "क्\u200dष"                                                => "क्\u200d",
      "क्ष"                                                      => "क्",
    }.each do |value, want|
      m = v222_textarea
      m.set_value(value)
      m, _ = m.update(Tea.key(Tea::KeyBackspace))
      m.value.should eq(want)
    end
  end

  it "TestClickMapsToGraphemeStart" do
    m = v222_textarea
    m.set_value("A👩‍💻BC")
    {0 => 0, 1 => 1, 2 => 1, 3 => 4, 4 => 5, 5 => 6}.each do |x, want|
      m.position_at(x + m.gutter_width, 0).col.should eq(want)
    end
  end

  it "TestVerticalCursorUsesGraphemeWidth" do
    m = v222_textarea
    m.set_value("abcdef\n👩‍💻xyz")
    m.cursor_up
    m.set_cursor_column(4)
    m.cursor_down
    m.col.should eq(5)
  end

  it "TestTransposeSwapsGraphemes" do
    m = v222_textarea
    m.set_value("ab👩‍💻")
    m.transpose_left
    m.value.should eq("a👩‍💻b")
  end

  it "TestTypingComposesBeforeExistingText" do
    {"नमस्ते" => "क्ष", "🇸x" => "🇺🇸"}.each do |value, typed|
      m = v222_textarea
      m.set_value(value)
      m.cursor_start
      typed.each_char { |ch| m, _ = m.update(Tea.key(ch)) }
      want = case value
             when "नमस्ते" then "क्षनमस्ते"
             else               "🇺🇸🇸x"
             end
      m.value.should eq(want)
      m.col.should eq(typed.chars.size)
    end
  end

  it "TestWrapKeepsGraphemesWhole" do
    ["👩‍💻" * 12, "e\u0301" * 30, "नमस्ते" * 8].each do |value|
      m = v222_textarea
      runes = value.chars
      offset = 0
      m.wrap(runes, 10).each do |line|
        start, _ = Bubbles::Textarea.grapheme_at(runes, offset)
        start.should eq(offset)
        offset += line.size
      end
    end
  end

  it "TestDeleteWordLeftKeepsSpaceGrapheme" do
    m = v222_textarea
    m.set_value("ab \u0301cd")
    m.delete_word_left
    m.value.should eq("ab \u0301")
  end

  it "TestIndicConjunctIsOneGrapheme" do
    m = v222_textarea
    m.set_value("क्षत्रिय")
    stops = [] of Int32
    while m.col > 0
      m.character_left(false)
      stops << m.col
    end
    stops.should eq([7, 3, 0])
  end

  # Go: selection_test.go

  it "TestPositionAt" do
    ta = v222_selection_textarea("hello\nworld")
    {
      {0, 0}  => Bubbles::Textarea::Position.new(0, 0),
      {3, 0}  => Bubbles::Textarea::Position.new(0, 3),
      {0, 1}  => Bubbles::Textarea::Position.new(1, 0),
      {2, 1}  => Bubbles::Textarea::Position.new(1, 2),
      {40, 0} => Bubbles::Textarea::Position.new(0, 5),
      {0, -3} => Bubbles::Textarea::Position.new(0, 0),
      {0, 50} => Bubbles::Textarea::Position.new(1, 5),
    }.each do |(x, y), want|
      ta.position_at(x, y).should eq(want)
    end
  end

  it "TestPositionAtAccountsForGutter" do
    ta = Bubbles::Textarea.new
    ta.prompt = "> "
    ta.show_line_numbers = false
    ta.set_width(20)
    ta.set_height(3)
    ta.focus
    ta.set_value("hello")

    ta.position_at(2, 0).should eq(Bubbles::Textarea::Position.new(0, 0))
    ta.position_at(5, 0).should eq(Bubbles::Textarea::Position.new(0, 3))
    ta.position_at(0, 0).should eq(Bubbles::Textarea::Position.new(0, 0))
  end

  it "TestSelectedTextSingleLine" do
    ta = v222_selection_textarea("hello world")
    ta.begin_selection(0, 0)
    ta.extend_selection(5, 0)
    ta.end_selection

    ta.has_selection?.should be_true
    ta.selected_text.should eq("hello")
  end

  it "TestSelectedTextAcrossLines" do
    ta = v222_selection_textarea("one\ntwo\nthree")
    ta.begin_selection(2, 0)
    ta.extend_selection(1, 2)
    ta.end_selection
    ta.selected_text.should eq("e\ntwo\nt")
  end

  it "TestSelectedTextBackwardDrag" do
    forward = v222_selection_textarea("one\ntwo\nthree")
    forward.begin_selection(2, 0)
    forward.extend_selection(1, 2)
    forward.end_selection

    backward = v222_selection_textarea("one\ntwo\nthree")
    backward.begin_selection(1, 2)
    backward.extend_selection(2, 0)
    backward.end_selection

    backward.selected_text.should eq(forward.selected_text)
    backward.selected_text.should eq("e\ntwo\nt")
  end

  it "TestClickWithoutDragMakesNoSelection" do
    ta = v222_selection_textarea("hello world")
    ta.begin_selection(3, 0)
    ta.end_selection
    ta.has_selection?.should be_false
    ta.selected_text.should eq("")
  end

  it "TestExtendSelectionRequiresBegin" do
    ta = v222_selection_textarea("hello world")
    ta.extend_selection(5, 0)
    ta.has_selection?.should be_false
  end

  it "TestClearSelectionAPI" do
    ta = v222_selection_textarea("hello world")
    ta.begin_selection(0, 0)
    ta.extend_selection(5, 0)
    ta.end_selection
    ta.has_selection?.should be_true

    ta.clear_selection
    ta.has_selection?.should be_false
    ta.selected_text.should eq("")
  end

  it "TestSelectAllAPI" do
    ta = v222_selection_textarea("one\ntwo")
    ta.select_all
    ta.selected_text.should eq("one\ntwo")
  end

  it "TestKeyPressClearsSelection" do
    ta = v222_selection_textarea("hello world")
    ta.begin_selection(0, 0)
    ta.extend_selection(5, 0)
    ta.end_selection
    ta.has_selection?.should be_true

    ta, _ = ta.update(Tea.key('x'))
    ta.has_selection?.should be_false
  end

  it "TestSelectionRendersWithSelectionStyle" do
    ta = v222_selection_textarea("hello world")
    plain = ta.view

    ta.begin_selection(0, 0)
    ta.extend_selection(5, 0)
    ta.end_selection
    selected = ta.view

    selected.should_not eq(plain)
    Ansi.strip(selected).strip.should eq(Ansi.strip(plain).strip)
  end

  it "TestSelectionSurvivesSoftWrap" do
    ta = Bubbles::Textarea.new
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(10)
    ta.set_height(6)
    ta.focus
    ta.set_value("aaaaabbbbbccccc")

    pos = ta.position_at(0, 1)
    pos.row.should eq(0)
    pos.col.should eq(10)

    ta.begin_selection(0, 1)
    ta.extend_selection(5, 1)
    ta.end_selection
    ta.selected_text.should eq("ccccc")
  end

  it "TestSelectionEmptyBuffer" do
    ta = v222_selection_textarea("")
    ta.begin_selection(0, 0)
    ta.extend_selection(5, 3)
    ta.end_selection
    ta.select_all

    ta.has_selection?.should be_false
    ta.selected_text.should eq("")
    ta.view
  end

  it "TestSelectionRange" do
    ta = v222_selection_textarea("hello world")
    ta.begin_selection(0, 0)
    ta.extend_selection(5, 0)
    ta.end_selection

    start, finish, ok = ta.selection
    ok.should be_true
    start.should eq(Bubbles::Textarea::Position.new(0, 0))
    finish.should eq(Bubbles::Textarea::Position.new(0, 5))
  end

  # Go: textarea_test.go additions

  it "TestAutoResizeKeepsFirstSoftWrappedRowVisible" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(24)
    ta.set_height(1)
    ta.char_limit = 200

    "this is a long active line that should wrap to the next row while typing".each_char do |ch|
      ta, _ = ta.update(Tea.key(ch))
      ta.set_height(ta.total_visual_lines)
      ta.view
    end

    ta.viewport.y_offset.should eq(0)
    view = Ansi.strip(ta.view)
    view.should contain("this is a long active")
    view.should contain("typing")
  end

  it "TestBackspaceDeletesSelection" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(20)
    ta.set_height(5)
    ta = v222_send(ta, "hello world")
    ta.cursor_start

    6.times { ta, _ = ta.update(shift_key(Tea::KeyRight)) }
    ta, _ = ta.update(Tea.key(Tea::KeyBackspace))

    ta.value.should eq("world")
    ta.has_selection?.should be_false
  end

  it "TestCharLimitWideRunes" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.char_limit = 5
    ta = v222_send(ta, "你好世界龍")

    ta.value.chars.size.should eq(5)
    ta.length.should eq(5)
  end

  it "TestClearSelection" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(20)
    ta.set_height(5)
    ta = v222_send(ta, "hello")
    ta.select_all

    ta.has_selection?.should be_true
    ta.clear_selection
    ta.has_selection?.should be_false
    ta.selected_text.should eq("")
  end

  it "TestCopyErrMsgUnwrap" do
    underlying = V222ClipboardError.new("clipboard copy error")
    m = Bubbles::Textarea.new
    m.focus

    m, _ = m.update(Bubbles::Textarea::CopyErrMsg.new(underlying))
    m.err.should_not be_nil
    m.err.should be_a(Bubbles::Textarea::CopyErrMsg)
    m.err.try(&.cause).should eq(underlying)
  end

  it "TestDeleteForwardDeletesSelection" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(20)
    ta.set_height(5)
    ta = v222_send(ta, "hello world")
    ta.cursor_start

    5.times { ta, _ = ta.update(shift_key(Tea::KeyRight)) }
    ta, _ = ta.update(Tea.key(Tea::KeyDelete))
    ta.value.should eq(" world")
  end

  it "TestDeleteSelectionMultiLine" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(20)
    ta.set_height(10)

    ta = v222_send(ta, "line one")
    ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    ta = v222_send(ta, "line two")
    ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    ta = v222_send(ta, "line three")

    ta.move_to_begin
    9.times { ta, _ = ta.update(shift_key(Tea::KeyRight)) }
    9.times { ta, _ = ta.update(shift_key(Tea::KeyRight)) }

    ta.selected_text.should eq("line one\nline two\n")

    ta, _ = ta.update(Tea.key(Tea::KeyBackspace))
    ta.value.should eq("line three")
  end

  it "TestMaxContentHeight_Insertion" do
    cases = [
      {name: "exact multiline", initial: "", column: 0, input: "alpha\nbeta", width: 40, limit: 2, want: "alpha\nbeta", row: 1, col: 4, visual: 2},
      {name: "last permitted line", initial: "alpha\nbeta", column: 4, input: "\ngamma", width: 40, limit: 3, want: "alpha\nbeta\ngamma", row: 2, col: 5, visual: 3},
      {name: "single line at limit", initial: "alpha", column: 5, input: "beta", width: 40, limit: 1, want: "alphabeta", row: 0, col: 9, visual: 1},
      {name: "midline suffix", initial: "prefixsuffix", column: 6, input: "alpha\nbeta", width: 40, limit: 2, want: "prefixalpha\nbetasuffix", row: 1, col: 4, visual: 2},
      {name: "single line with suffix", initial: "abef", column: 2, input: "cd", width: 40, limit: 1, want: "abcdef", row: 0, col: 4, visual: 1},
      {name: "first line wraps", initial: "abc", column: 3, input: "de\nx", width: 5, limit: 3, want: "abcde\nx", row: 1, col: 1, visual: 3},
      {name: "suffix wraps", initial: "abcdef", column: 3, input: "x\nyz", width: 5, limit: 3, want: "abcx\nyzdef", row: 1, col: 2, visual: 3},
      {name: "suffix exceeds limit", initial: "abcdef", column: 3, input: "x\nyz", width: 5, limit: 2, want: "abcxdef", row: 0, col: 4, visual: 2},
      {name: "middle line wraps", initial: "", column: 0, input: "a\nabcdef\nb", width: 5, limit: 4, want: "a\nabcdef\nb", row: 2, col: 1, visual: 4},
      {name: "wide suffix wraps", initial: "界界", column: 1, input: "ab\nc界", width: 5, limit: 3, want: "界ab\nc界界", row: 1, col: 2, visual: 3},
      {name: "wide suffix exceeds limit", initial: "界界", column: 1, input: "ab\nc界", width: 5, limit: 2, want: "界ab界", row: 0, col: 3, visual: 2},
      {name: "trailing newline", initial: "", column: 0, input: "alpha\n", width: 40, limit: 2, want: "alpha\n", row: 1, col: 0, visual: 2},
      {name: "excess lines trimmed", initial: "", column: 0, input: "a\nb\nc", width: 40, limit: 2, want: "a\nb", row: 1, col: 1, visual: 2},
      {name: "single line exceeds limit", initial: "abc", column: 3, input: "de", width: 5, limit: 1, want: "abc", row: 0, col: 3, visual: 1},
      {name: "unlimited", initial: "", column: 0, input: "alpha\nbeta", width: 40, limit: 0, want: "alpha\nbeta", row: 1, col: 4, visual: 2},
      {name: "empty insertion", initial: "alpha", column: 2, input: "", width: 40, limit: 1, want: "alpha", row: 0, col: 2, visual: 1},
    ]

    cases.each do |tc|
      {false, true}.each do |dynamic|
        {false, true}.each do |paste|
          ta = Bubbles::Textarea.new
          ta.prompt = ""
          ta.show_line_numbers = false
          ta.dynamic_height = dynamic
          ta.set_width(tc[:width])
          ta.focus
          ta.set_value(tc[:initial])
          ta.set_cursor_column(tc[:column])
          ta.max_content_height = tc[:limit]

          if paste
            ta, _ = ta.update(Tea::PasteMsg.new(content: tc[:input]))
          else
            ta.insert_string(tc[:input])
          end

          label = "#{tc[:name]} dynamic=#{dynamic} paste=#{paste}"
          ta.value.should eq(tc[:want]), label
          {ta.line, ta.column}.should eq({tc[:row], tc[:col]}), label
          ta.total_visual_lines.should eq(tc[:visual]), label
          ta.height.should eq(tc[:visual]) if dynamic
        end
      end
    end
  end

  it "TestMaxContentHeight_SingleRuneAtLimit" do
    {false, true}.each do |use_key|
      ta = Bubbles::Textarea.new
      ta.prompt = ""
      ta.show_line_numbers = false
      ta.set_width(5)
      ta.focus
      ta.set_value("abc")
      ta.max_content_height = 1

      "de".each_char do |ch|
        if use_key
          ta, _ = ta.update(Tea.key(ch))
        else
          ta.insert_rune(ch)
        end
      end

      ta.value.should eq("abcd")
      {ta.line, ta.column, ta.total_visual_lines}.should eq({0, 4, 1})
    end
  end

  it "TestNewlineReplacesSelection" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(20)
    ta.set_height(10)
    ta = v222_send(ta, "hello world")
    ta.cursor_start

    6.times { ta, _ = ta.update(shift_key(Tea::KeyRight)) }
    ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    ta.value.should eq("\nworld")
  end

  it "TestPasteErrMsgUnwrap" do
    underlying = V222ClipboardError.new("clipboard paste error")
    m = Bubbles::Textarea.new
    m.focus

    m, _ = m.update(Bubbles::Textarea::PasteErrMsg.new(underlying))
    m.err.should_not be_nil
    m.err.should be_a(Bubbles::Textarea::PasteErrMsg)
    m.err.try(&.cause).should eq(underlying)
  end

  it "TestPasteReplacesSelection" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(40)
    ta.set_height(5)
    ta = v222_send(ta, "hello world")
    ta.cursor_start

    5.times { ta, _ = ta.update(shift_key(Tea::KeyRight)) }
    ta, _ = ta.update(Bubbles::Textarea::PasteMsg.new("REPLACED".chars))
    ta.value.should eq("REPLACED world")
  end

  it "TestSelectAll" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(20)
    ta.set_height(10)
    ta = v222_send(ta, "hello world")
    ta.select_all
    ta.selected_text.should eq("hello world")
  end

  it "TestSelectionCharacterBackward" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(20)
    ta.set_height(5)
    ta = v222_send(ta, "hello")

    5.times { ta, _ = ta.update(shift_key(Tea::KeyLeft)) }
    ta.selected_text.should eq("hello")
  end

  it "TestSelectionCharacterForward" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(20)
    ta.set_height(5)
    ta = v222_send(ta, "hello world")
    ta.cursor_start

    5.times { ta, _ = ta.update(shift_key(Tea::KeyRight)) }
    ta.selected_text.should eq("hello")
    ta.has_selection?.should be_true
  end

  it "TestSelectionClearedOnMovement" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(20)
    ta.set_height(5)
    ta = v222_send(ta, "hello")
    ta.cursor_start

    ta, _ = ta.update(shift_key(Tea::KeyRight))
    ta.has_selection?.should be_true
    ta, _ = ta.update(Tea.key(Tea::KeyRight))
    ta.has_selection?.should be_false
  end

  it "TestSelectionClearedOnType" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(20)
    ta.set_height(5)
    ta = v222_send(ta, "hello")
    ta.cursor_start

    ta, _ = ta.update(shift_key(Tea::KeyRight))
    ta.has_selection?.should be_true
    ta, _ = ta.update(Tea.key('x'))
    ta.has_selection?.should be_false
  end

  it "TestSelectionMultiLine" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(20)
    ta.set_height(10)
    ta = v222_send(ta, "line one")
    ta, _ = ta.update(Tea.key(Tea::KeyEnter))
    ta = v222_send(ta, "line two")
    ta.move_to_begin

    ta, _ = ta.update(shift_key(Tea::KeyDown))
    ta.selected_text.should eq("line one\n")

    8.times { ta, _ = ta.update(shift_key(Tea::KeyRight)) }
    ta.selected_text.should eq("line one\nline two")
  end

  it "TestSelectionRangeOrdering" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(20)
    ta.set_height(5)
    ta = v222_send(ta, "hello world")

    5.times { ta, _ = ta.update(shift_key(Tea::KeyLeft)) }
    ta.selected_text.should eq("world")
  end

  it "TestSelectionRendering" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(20)
    ta.set_height(5)
    ta = v222_send(ta, "hello")
    ta.cursor_start

    3.times { ta, _ = ta.update(shift_key(Tea::KeyRight)) }
    ta.view.should_not be_empty
  end

  it "TestSelectionWordForward" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(20)
    ta.set_height(5)
    ta = v222_send(ta, "hello world foo")
    ta.cursor_start

    ta, _ = ta.update(Tea.key(Tea::KeyRight, Ultraviolet::ModShift | Ultraviolet::ModAlt))
    ta.selected_text.should eq("hello")
  end

  it "TestSetValueViewportReposition" do
    ta = v222_textarea
    ta.set_height(3)
    ta.set_width(40)
    ta.set_value("line1\nline2\nline3\nline4\nline5")

    (ta.scroll_y_offset + ta.height - 1).should be >= ta.line_count - 1
  end

  it "TestSetWidthDoesNotExpandToMaximum" do
    m = v222_textarea
    m.set_width(40)
    want = m.width
    m.max_width = 80
    m.set_width(40)
    m.width.should eq(want)
    m.max_width = 0
    m.set_width(40)
    m.width.should eq(want)
  end

  it "TestSetWidthHonorsUsableMaximum" do
    m = v222_textarea
    m.set_width(40)
    want = m.width
    m.max_width = 40
    m.set_width(80)
    m.width.should eq(want)
  end

  it "TestSetWidth_MaxWidthBelowReservedWidth" do
    [{false, 2}, {true, 1}].each do |show_line_numbers, max_width|
      ta = v222_textarea
      ta.show_line_numbers = show_line_numbers
      ta.max_width = max_width
      ta.set_width(80)
      ta.focus

      ta.width.should be >= 1

      ta.set_value("a b  ")
      ta.set_cursor_column(1)
      ta.view
      ta, _ = ta.update(Tea.key(Tea::KeyLeft))
      ta.view
    end
  end

  it "TestShiftBackspaceDeletesCharacterBackward" do
    ta = v222_textarea
    ta.set_value("abc")
    ta, _ = ta.update(shift_key(Tea::KeyBackspace))
    ta.value.should eq("ab")
  end

  it "TestTypingLastWordFillsWidthDoesNotReflow" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(10)
    ta.set_height(3)

    "1 2 3 4 56".each_char { |ch| ta, _ = ta.update(Tea.key(ch)) }
    Ansi.strip(ta.view).lines[0].should eq("1 2 3 4 56")

    ta, _ = ta.update(Tea.key('7'))
    lines = Ansi.strip(ta.view).lines
    lines[0].rstrip.should eq("1 2 3 4")
    lines[1].rstrip.should eq("567")
  end

  it "TestTypingReplacesSelection" do
    ta = v222_textarea
    ta.prompt = ""
    ta.show_line_numbers = false
    ta.set_width(20)
    ta.set_height(5)
    ta = v222_send(ta, "hello world")
    ta.cursor_start

    5.times { ta, _ = ta.update(shift_key(Tea::KeyRight)) }
    ta.selected_text.should eq("hello")

    ta, _ = ta.update(Tea.key('X'))
    ta.value.should eq("X world")
    ta.has_selection?.should be_false
  end

  it "TestVerticalNavigationThroughSoftWraps" do
    next_line = "\nabcdefghijklmnop"
    cases = [
      {"short line", "a" * 19 + next_line, [{0, 7}, {1, 7}]},
      {"exact width", "a" * 20 + next_line, [{0, 7}, {0, 20}, {1, 7}]},
      {"over width", "a" * 21 + next_line, [{0, 7}, {0, 21}, {1, 7}]},
      {"word wrap", "one two three four five" + next_line, [{0, 7}, {0, 23}, {1, 7}]},
      {"multiple exact wraps", "a" * 40 + next_line, [{0, 7}, {0, 27}, {0, 40}, {1, 7}]},
      {"exact width with spaces", "123456789 123456789 " + next_line, [{0, 7}, {0, 20}, {1, 7}]},
      {"wide runes", "你好" * 5 + next_line, [{0, 4}, {0, 10}, {1, 8}]},
      {"mixed width runes", "a" * 18 + "你" + next_line, [{0, 7}, {0, 19}, {1, 7}]},
      {"exact width at end of buffer", "a" * 20, [{0, 7}, {0, 20}]},
    ]

    cases.each do |name, value, want|
      ta = v222_textarea
      ta.prompt = ""
      ta.show_line_numbers = false
      ta.set_width(20)
      ta.set_height(10)
      ta.set_virtual_cursor(false)
      ta.set_value(value)
      ta.move_to_begin
      ta.set_cursor_column(want[0][1])

      check = ->(label : String, index : Int32) do
        {ta.line, ta.column}.should eq({want[index][0], want[index][1]}), "#{name} #{label}"
        ta.cursor.try(&.y).should eq(index), "#{name} #{label} row"
      end

      check.call("start", 0)
      (1...want.size).each do |i|
        ta, _ = ta.update(Tea.key(Tea::KeyDown))
        check.call("down", i)
      end
      ta, _ = ta.update(Tea.key(Tea::KeyDown))
      check.call("down at end", want.size - 1)

      (0...(want.size - 1)).to_a.reverse.each do |i|
        ta, _ = ta.update(Tea.key(Tea::KeyUp))
        check.call("up", i)
      end
      ta, _ = ta.update(Tea.key(Tea::KeyUp))
      check.call("up at start", 0)
    end
  end

  it "TestWordLeftStopsAtStart" do
    cases = [
      {name: "empty input", value: "", row: 0, col: 0, want_row: 0, want_col: 0},
      {name: "buffer start before whitespace", value: " word", row: 0, col: 0, want_row: 0, want_col: 0},
      {name: "inside leading whitespace", value: "   word", row: 0, col: 2, want_row: 0, want_col: 0},
      {name: "multiline whitespace prefix", value: "  \n  word", row: 1, col: 2, want_row: 0, want_col: 0},
      {name: "previous word", value: "first second", row: 0, col: 12, want_row: 0, want_col: 6},
    ]

    cases.each do |tc|
      ta = v222_textarea
      ta.set_value(tc[:value])
      ta.row = tc[:row]
      ta.col = tc[:col]
      ta.word_left
      {ta.row, ta.col}.should eq({tc[:want_row], tc[:want_col]}), tc[:name]
    end
  end

  it "TestWrapLastWordFillsWidth" do
    m = v222_textarea
    {
      "1234567890"  => ["1234567890", " "],
      "1 2 3 4 5"   => ["1 2 3 4 5 "],
      "1 2 3 4 56"  => ["1 2 3 4 56", " "],
      "1 2 3 4 567" => ["1 2 3 4 ", "567 "],
      "1 2 3 4 中"   => ["1 2 3 4 中", " "],
    }.each do |input, want|
      m.wrap(input.chars, 10).map(&.join).should eq(want)
    end
  end
end
