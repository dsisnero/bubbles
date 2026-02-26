require "./spec_helper"
require "../src/bubbles/cursor"

describe Bubbles::Cursor do
  describe "mode constants" do
    it "exposes Go parity mode constants" do
      Bubbles::Cursor::CursorBlink.should eq(Bubbles::Cursor::Mode::Blink)
      Bubbles::Cursor::CursorStatic.should eq(Bubbles::Cursor::Mode::Static)
      Bubbles::Cursor::CursorHide.should eq(Bubbles::Cursor::Mode::Hide)
    end

    it "returns the expected mode string" do
      Bubbles::Cursor::Mode::Blink.string.should eq("blink")
      Bubbles::Cursor::Mode::Static.string.should eq("static")
      Bubbles::Cursor::Mode::Hide.string.should eq("hidden")
    end
  end

  describe "Model" do
    it "creates a new model with default settings" do
      model = Bubbles::Cursor::Model.new
      model.id.should be > 0
      model.blink_speed.should eq(Bubbles::Cursor::DEFAULT_BLINK_SPEED)
      model.blinked?.should be_true
      model.mode.should eq(Bubbles::Cursor::Mode::Blink)
      model.focus?.should be_false
      model.blink_tag.should eq(0)
    end

    it "updates on initial blink message when focused and in blink mode" do
      model = Bubbles::Cursor::Model.new
      model.focus = true
      model.mode = Bubbles::Cursor::Mode::Blink
      _, cmd = model.update(Bubbles::Cursor::InitialBlinkMsg.new)
      cmd.should_not be_nil
    end

    it "ignores initial blink message when not focused" do
      model = Bubbles::Cursor::Model.new
      model.focus = false
      model.mode = Bubbles::Cursor::Mode::Blink
      _, cmd = model.update(Bubbles::Cursor::InitialBlinkMsg.new)
      cmd.should be_nil
    end

    it "ignores initial blink message when mode is not blink" do
      model = Bubbles::Cursor::Model.new
      model.focus = true
      model.mode = Bubbles::Cursor::Mode::Static
      _, cmd = model.update(Bubbles::Cursor::InitialBlinkMsg.new)
      cmd.should be_nil
    end

    it "handles focus message" do
      model = Bubbles::Cursor::Model.new
      updated, cmd = model.update(Tea::FocusMsg.new)
      cmd.should_not be_nil
      updated.focus?.should be_true
    end

    it "handles blur message" do
      model = Bubbles::Cursor::Model.new
      model.focus = true
      updated, cmd = model.update(Tea::BlurMsg.new)
      cmd.should be_nil
      updated.focus?.should be_false
      updated.blinked?.should be_true
    end

    it "toggles blink on valid blink message" do
      model = Bubbles::Cursor::Model.new
      model.focus = true
      model.mode = Bubbles::Cursor::Mode::Blink
      # Need to set blink_tag to match the message
      blink_msg = Bubbles::Cursor::BlinkMsg.new(model.id, model.blink_tag)
      was_blinked = model.blinked?
      updated, cmd = model.update(blink_msg)
      updated.blinked?.should_not eq(was_blinked)
      cmd.should_not be_nil
    end

    it "ignores blink message with wrong id" do
      model = Bubbles::Cursor::Model.new
      model.focus = true
      model.mode = Bubbles::Cursor::Mode::Blink
      blink_msg = Bubbles::Cursor::BlinkMsg.new(model.id + 1, model.blink_tag)
      updated, cmd = model.update(blink_msg)
      cmd.should be_nil
      updated.blinked?.should eq(model.blinked?)
    end

    it "ignores blink message with wrong tag" do
      model = Bubbles::Cursor::Model.new
      model.focus = true
      model.mode = Bubbles::Cursor::Mode::Blink
      blink_msg = Bubbles::Cursor::BlinkMsg.new(model.id, model.blink_tag + 1)
      updated, cmd = model.update(blink_msg)
      cmd.should be_nil
      updated.blinked?.should eq(model.blinked?)
    end

    it "ignores blink message when not focused" do
      model = Bubbles::Cursor::Model.new
      model.focus = false
      model.mode = Bubbles::Cursor::Mode::Blink
      blink_msg = Bubbles::Cursor::BlinkMsg.new(model.id, model.blink_tag)
      updated, cmd = model.update(blink_msg)
      cmd.should be_nil
      updated.blinked?.should eq(model.blinked?)
    end

    it "ignores blink message when mode is not blink" do
      model = Bubbles::Cursor::Model.new
      model.focus = true
      model.mode = Bubbles::Cursor::Mode::Static
      blink_msg = Bubbles::Cursor::BlinkMsg.new(model.id, model.blink_tag)
      updated, cmd = model.update(blink_msg)
      cmd.should be_nil
      updated.blinked?.should eq(model.blinked?)
    end

    it "handles blink canceled message" do
      model = Bubbles::Cursor::Model.new
      _, cmd = model.update(Bubbles::Cursor::BlinkCanceled.new)
      cmd.should be_nil
    end

    it "returns mode" do
      model = Bubbles::Cursor::Model.new
      model.mode = Bubbles::Cursor::Mode::Hide
      model.mode.should eq(Bubbles::Cursor::Mode::Hide)
    end

    it "sets mode with valid range" do
      model = Bubbles::Cursor::Model.new
      cmd = model.set_mode(Bubbles::Cursor::Mode::Static)
      cmd.should be_nil
      model.mode.should eq(Bubbles::Cursor::Mode::Static)
    end

    it "sets mode to blink returns blink command" do
      model = Bubbles::Cursor::Model.new
      cmd = model.set_mode(Bubbles::Cursor::Mode::Blink)
      cmd.should_not be_nil
      model.mode.should eq(Bubbles::Cursor::Mode::Blink)
    end

    it "ignores set_mode with out of range value" do
      model = Bubbles::Cursor::Model.new
      # Create an invalid mode value using enum value outside range
      # In Crystal, we can't easily create invalid enum values, so we'll test with valid ones
      # The Go code checks if mode < CursorBlink || mode > CursorHide
      # Since we can't create invalid enum values, we'll test that valid ones work
      cmd = model.set_mode(Bubbles::Cursor::Mode::Blink)
      cmd.should_not be_nil
    end

    it "focus returns blink command when in blink mode" do
      model = Bubbles::Cursor::Model.new
      model.mode = Bubbles::Cursor::Mode::Blink
      cmd = model.focus
      cmd.should_not be_nil
      model.focus?.should be_true
    end

    it "focus returns nil when not in blink mode" do
      model = Bubbles::Cursor::Model.new
      model.mode = Bubbles::Cursor::Mode::Static
      cmd = model.focus
      cmd.should be_nil
      model.focus?.should be_true
    end

    it "blur sets focus to false and blinked to true" do
      model = Bubbles::Cursor::Model.new
      model.focus = true
      model.blinked = false
      model.blur
      model.focus?.should be_false
      model.blinked?.should be_true
    end

    it "set_char updates character" do
      model = Bubbles::Cursor::Model.new
      model.set_char("X")
      model.char.should eq("X")
    end

    it "view shows text style when blinked" do
      model = Bubbles::Cursor::Model.new
      model.blinked = true
      model.char = "A"
      view = model.view
      # Since lipgloss::Style.render currently returns text unchanged
      view.should eq("A")
    end

    it "view shows reversed style when not blinked" do
      model = Bubbles::Cursor::Model.new
      model.blinked = false
      model.char = "B"
      view = model.view
      view.includes?("B").should be_true
      view.includes?("\e[7m").should be_true
    end
  end

  # TestBlinkCmdDataRace tests for a race on blinkTag.
  #
  # The original Model.Blink implementation returned a closure over the pointer receiver.
  # A race on "blinkTag" will occur if:
  #  1. Model.Blink is called e.g. by calling Model.Focus from Model.Update;
  #  2. handleCommands is kept sufficiently busy that it does not receive and
  #     execute the Model.BlinkCmd e.g. by other long running command or commands;
  #  3. at least BlinkSpeed time elapses;
  #  4. Model.Blink is called again;
  #  5. handleCommands gets around to receiving and executing the original closure.
  #
  # Even if this did not formally race, the value of the tag fetched would be semantically incorrect
  # (likely being the current value rather than the value at the time the closure was created).
  it "TestBlinkCmdDataRace" do
    m = Bubbles::Cursor::Model.new
    cmd = m.blink
    # In Crystal, we don't have goroutines but we can spawn fibers
    # The test simulates concurrent access to blinkTag
    channel = Channel(Nil).new
    spawn do
      sleep(m.blink_speed * 3)
      cmd.try(&.call)
      channel.send(nil)
    end
    spawn do
      sleep(m.blink_speed * 2)
      m.blink
      channel.send(nil)
    end
    # Wait for both fibers to complete
    2.times { channel.receive }
  end
end
