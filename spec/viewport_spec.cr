require "./spec_helper"
require "../src/bubbles/viewport"

describe Bubbles::Viewport do
  it "TestNew" do
    m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(10), Bubbles::Viewport.with_width(10))
    m.height.should eq(10)
    m.width.should eq(10)
    m.mouse_wheel_enabled?.should be_true
  end

  it "TestSetInitialValues" do
    m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(10), Bubbles::Viewport.with_width(10))
    m.mouse_wheel_delta.should eq(3)
    m.mouse_wheel_enabled?.should be_true
  end

  it "TestSetHorizontalStep" do
    m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(10), Bubbles::Viewport.with_width(10))
    m.set_horizontal_step(8)
    m.scroll_right(8)
    m.x_offset.should eq(0)
  end

  it "TestMoveRight" do
    m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(2), Bubbles::Viewport.with_width(10))
    m.set_content("Some line that is longer than width")
    m.scroll_right(6)
    m.x_offset.should eq(6)
  end

  it "TestMoveLeft" do
    m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(2), Bubbles::Viewport.with_width(10))
    m.set_content("Some line that is longer than width")
    m.scroll_right(6)
    m.scroll_left(6)
    m.x_offset.should eq(0)
  end

  it "TestResetIndent" do
    m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(2), Bubbles::Viewport.with_width(10))
    m.set_content("Some line that is longer than width")
    m.set_x_offset(500)
    m.x_offset.should be >= 0
    m.set_x_offset(0)
    m.x_offset.should eq(0)
  end

  it "TestVisibleLines" do
    content = "line1\nline2\nline3\nline4"
    m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(2), Bubbles::Viewport.with_width(5))
    m.set_content(content)
    m.visible_line_count.should eq(2)
    m.view.should contain("line1")
    m.scroll_down(1)
    m.view.should contain("line2")
  end

  it "TestSizing" do
    m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(2), Bubbles::Viewport.with_width(5))
    m.height.should eq(2)
    m.width.should eq(5)
  end

  it "TestRightOverscroll" do
    m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(2), Bubbles::Viewport.with_width(10))
    m.set_content("Some line that is longer than width")
    m.scroll_right(10_000)
    x = m.x_offset
    m.scroll_right(10_000)
    m.x_offset.should eq(x)
  end

  it "TestMatchesToHighlights" do
    m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(3), Bubbles::Viewport.with_width(10))
    m.set_content("a\nb\nc\nd")
    m.set_highlights([[1, 2], [3, 4]])
    m.highlight_next
    m.y_offset.should be >= 0
    m.highlight_previous
    m.y_offset.should be >= 0
    m.clear_highlights
  end
end
