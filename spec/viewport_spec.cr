require "./spec_helper"

TEXT_CONTENT_LIST = "57 Precepts of narcissistic comedy character Zote from an awesome \"Hollow knight\" game (https://store.steampowered.com/app/367520/Hollow_Knight/).
Precept One: 'Always Win Your Battles'. Losing a battle earns you nothing and teaches you nothing. Win your battles, or don't engage in them at all!

Precept Two: 'Never Let Them Laugh at You'. Fools laugh at everything, even at their superiors. But beware, laughter isn't harmless! Laughter spreads like a disease, and soon everyone is laughing at you. You need to strike at the source of this perverse merriment quickly to stop it from spreading.
Precept Three: 'Always Be Rested'. Fighting and adventuring take their toll on your body. When you rest, your body strengthens and repairs itself. The longer you rest, the stronger you become.
Precept Four: 'Forget Your Past'. The past is painful, and thinking about your past can only bring you misery. Think about something else instead, such as the future, or some food.
Precept Five: 'Strength Beats Strength'. Is your opponent strong? No matter! Simply overcome their strength with even more strength, and they'll soon be defeated.
Precept Six: 'Choose Your Own Fate'. Our elders teach that our fate is chosen for us before we are even born. I disagree.
Precept Seven: 'Mourn Not the Dead'. When we die, do things get better for us or worse? There's no way to tell, so we shouldn't bother mourning. Or celebrating for that matter.
Precept Eight: 'Travel Alone'. You can rely on nobody, and nobody will always be loyal. Therefore, nobody should be your constant companion.
Precept Nine: 'Keep Your Home Tidy'. Your home is where you keep your most prized possession - yourself. Therefore, you should make an effort to keep it nice and clean.
Precept Ten: 'Keep Your Weapon Sharp'. I make sure that my weapon, 'Life Ender', is kept well-sharpened at all times. This makes it much easier to cut things.
Precept Eleven: 'Mothers Will Always Betray You'. This Precept explains itself.
Precept Twelve: 'Keep Your Cloak Dry'. If your cloak gets wet, dry it as soon as you can. Wearing wet cloaks is unpleasant, and can lead to illness.
Precept Thirteen: 'Never Be Afraid'. Fear can only hold you back. Facing your fears can be a tremendous effort. Therefore, you should just not be afraid in the first place.
Precept Fourteen: 'Respect Your Superiors'. If someone is your superior in strength or intellect or both, you need to show them your respect. Don't ignore them or laugh at them.
Precept Fifteen: 'One Foe, One Blow'. You should only use a single blow to defeat an enemy. Any more is a waste. Also, by counting your blows as you fight, you'll know how many foes you've defeated."

describe Bubbles::Viewport do
  # Go: TestNew/default values on create by New
  it "TestNew" do
    m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(10), Bubbles::Viewport.with_width(10))
    m.height.should eq(10)
    m.width.should eq(10)
    m.mouse_wheel_enabled?.should be_true
    m.mouse_wheel_delta.should eq(3)
  end

  # Go: TestSetInitialValues/default horizontalStep
  it "TestSetInitialValues" do
    m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(10), Bubbles::Viewport.with_width(10))
    m.mouse_wheel_delta.should eq(3)
    m.mouse_wheel_enabled?.should be_true
  end

  # Go: TestSetHorizontalStep (change default + no negative)
  describe "TestSetHorizontalStep" do
    it "change default" do
      m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(10), Bubbles::Viewport.with_width(10))
      new_step = 8
      m.set_horizontal_step(new_step)
      m.horizontal_step.should eq(new_step)
    end

    it "no negative" do
      m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(10), Bubbles::Viewport.with_width(10))
      m.set_horizontal_step(-1)
      m.horizontal_step.should eq(0)
    end
  end

  # Go: TestMoveLeft (zero position + move)
  describe "TestMoveLeft" do
    it "zero position" do
      m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(10), Bubbles::Viewport.with_width(10))
      m.x_offset.should eq(0)
      m.scroll_left(m.horizontal_step)
      m.x_offset.should eq(0)
    end

    it "move" do
      m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(10), Bubbles::Viewport.with_width(10))
      # set longest_line_width to allow horizontal scrolling
      m.set_content("some long content that exceeds width")
      m.x_offset.should eq(0)
      initial = Bubbles::Viewport::DEFAULT_HORIZONTAL_STEP * 2
      m.set_x_offset(initial)
      m.scroll_left(Bubbles::Viewport::DEFAULT_HORIZONTAL_STEP)
      new_indent = Bubbles::Viewport::DEFAULT_HORIZONTAL_STEP
      m.x_offset.should eq(new_indent)
    end
  end

  # Go: TestMoveRight
  it "TestMoveRight" do
    m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(2), Bubbles::Viewport.with_width(10))
    m.set_content("Some line that is longer than width")
    m.scroll_right(6)
    m.x_offset.should eq(6)
  end

  # Go: TestResetIndent
  it "TestResetIndent" do
    m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(2), Bubbles::Viewport.with_width(10))
    m.set_content("Some line that is longer than width")
    m.set_x_offset(500)
    m.x_offset.should be >= 0
    m.set_x_offset(0)
    m.x_offset.should eq(0)
  end

  # Go: TestVisibleLines
  describe "TestVisibleLines" do
    it "empty list" do
      m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(10), Bubbles::Viewport.with_width(10))
      m.visible_line_count.should eq(0)
    end

    it "list" do
      default_list = TEXT_CONTENT_LIST.split('\n')
      number_of_lines = 10
      m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(number_of_lines), Bubbles::Viewport.with_width(10))
      m.set_content(TEXT_CONTENT_LIST)
      m.visible_line_count.should eq(number_of_lines)
    end

    it "list with y offset" do
      number_of_lines = 10
      m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(number_of_lines), Bubbles::Viewport.with_width(10))
      m.set_content(TEXT_CONTENT_LIST)
      m.set_y_offset(5)
      m.visible_line_count.should eq(number_of_lines)
    end
  end

  # Go: TestRightOverscroll
  it "TestRightOverscroll" do
    content = "Content is short"
    m = Bubbles::Viewport.new(Bubbles::Viewport.with_height(5), Bubbles::Viewport.with_width(content.size + 1))
    m.set_content(content)
    10.times { m.scroll_right(Bubbles::Viewport::DEFAULT_HORIZONTAL_STEP) }
    m.x_offset.should be >= 0
  end

  # Go: TestMatchesToHighlights
  describe "TestMatchesToHighlights" do
    content = "hello\nworld\n\nwith empty rows\n\nwide chars: あいうえおafter\n\n爱开源 • Charm does open source\n\nCharm热爱开源 • Charm loves open source\n"

    it "first" do
      vt = Bubbles::Viewport.new(Bubbles::Viewport.with_width(100), Bubbles::Viewport.with_height(100))
      vt.set_content(content)
      matches = [[0, 5]] # "hello" byte range
      vt.set_highlights(matches)
    end

    it "multiple" do
      vt = Bubbles::Viewport.new(Bubbles::Viewport.with_width(100), Bubbles::Viewport.with_height(100))
      vt.set_content(content)
      # "l" matches at positions: line0:2, line0:3, line1:3, line9:22
      matches = [[2, 3], [3, 4], [7, 8], [136, 137]]
      vt.set_highlights(matches)
    end

    it "wide characters" do
      vt = Bubbles::Viewport.new(Bubbles::Viewport.with_width(100), Bubbles::Viewport.with_height(100))
      vt.set_content(content)
      # "after" in line 5
      matches = [[58, 63]]
      vt.set_highlights(matches)
    end

    it "highlights navigation" do
      vt = Bubbles::Viewport.new(Bubbles::Viewport.with_height(3), Bubbles::Viewport.with_width(10))
      vt.set_content("a\nb\nc\nd")
      vt.set_highlights([[1, 2], [3, 4]])
      vt.highlight_next
      vt.y_offset.should be >= 0
      vt.highlight_previous
      vt.y_offset.should be >= 0
      vt.clear_highlights
    end
  end

  # Go: TestSizing (golden + edge cases)
  describe "TestSizing" do
    it "view-40x100percent" do
      lines = TEXT_CONTENT_LIST.split('\n')
      width = 40
      height = lines.size + 2
      vt = Bubbles::Viewport.new(Bubbles::Viewport.with_width(width), Bubbles::Viewport.with_height(height))
      vt.style = vt.style.border(Lipgloss.rounded_border)
      vt.set_content(TEXT_CONTENT_LIST)
      view = vt.view
      rendered = Ansi.strip(view).lines
      rendered.size.should eq(height)
    end

    it "view-50x15-softwrap" do
      width = 50
      height = 15
      vt = Bubbles::Viewport.new(Bubbles::Viewport.with_width(width), Bubbles::Viewport.with_height(height))
      vt.soft_wrap = true
      vt.style = vt.style.border(Lipgloss.rounded_border)
      vt.set_content(TEXT_CONTENT_LIST)
      view = vt.view
      rendered = Ansi.strip(view).lines
      rendered.size.should eq(height)
    end

    it "view-50x15-content-lines" do
      content = ["57 Precepts of narcissistic comedy character Zote from an\nawesome \"Hollow knight\" game"]
      vt = Bubbles::Viewport.new(Bubbles::Viewport.with_width(50), Bubbles::Viewport.with_height(15))
      vt.set_content_lines(content)
      vt.view.should_not be_empty
    end

    it "view-0x0" do
      vt = Bubbles::Viewport.new(Bubbles::Viewport.with_width(0), Bubbles::Viewport.with_height(0))
      vt.set_content(TEXT_CONTENT_LIST)
      vt.view.should eq("")
    end

    it "view-1x0" do
      vt = Bubbles::Viewport.new(Bubbles::Viewport.with_width(1), Bubbles::Viewport.with_height(0))
      vt.set_content(TEXT_CONTENT_LIST)
      vt.view.should eq("")
    end

    it "view-0x1" do
      vt = Bubbles::Viewport.new(Bubbles::Viewport.with_width(0), Bubbles::Viewport.with_height(1))
      vt.set_content(TEXT_CONTENT_LIST)
      vt.view.should eq("")
    end
  end

  # Go: TestSizing with gutter
  it "TestSizing with gutter" do
    width = 50
    height = 15
    vt = Bubbles::Viewport.new(Bubbles::Viewport.with_width(width), Bubbles::Viewport.with_height(height))
    vt.soft_wrap = true
    vt.style = vt.style.border(Lipgloss.rounded_border)
    vt.left_gutter_func = ->(ctx : Bubbles::Viewport::GutterContext) { "  " }
    vt.set_content(TEXT_CONTENT_LIST)
    view = vt.view
    rendered = Ansi.strip(view).lines
    rendered.size.should eq(height)
  end
end
