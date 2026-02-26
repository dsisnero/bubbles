require "./spec_helper"
require "../src/bubbles/spinner"

describe Bubbles::Spinner do
  it "TestSpinnerNew default and with spinner" do
    s = Bubbles::Spinner.new
    s.spinner.fps.should eq(Bubbles::Spinner::Line.fps)
    s.spinner.frames.should eq(Bubbles::Spinner::Line.frames)

    custom = Bubbles::Spinner::SpinnerData.new(["a", "b", "c", "d"], 16.milliseconds)
    s2 = Bubbles::Spinner.new(Bubbles::Spinner.with_spinner(custom))
    s2.spinner.fps.should eq(custom.fps)
    s2.spinner.frames.should eq(custom.frames)
  end

  it "TestSpinnerNew built-ins" do
    tests = {
      "Line"    => Bubbles::Spinner::Line,
      "Dot"     => Bubbles::Spinner::Dot,
      "MiniDot" => Bubbles::Spinner::MiniDot,
      "Jump"    => Bubbles::Spinner::Jump,
      "Pulse"   => Bubbles::Spinner::Pulse,
      "Points"  => Bubbles::Spinner::Points,
      "Globe"   => Bubbles::Spinner::Globe,
      "Moon"    => Bubbles::Spinner::Moon,
      "Monkey"  => Bubbles::Spinner::Monkey,
    }

    tests.each_value do |spinner|
      got = Bubbles::Spinner.new(Bubbles::Spinner.with_spinner(spinner)).spinner
      got.fps.should eq(spinner.fps)
      got.frames.should eq(spinner.frames)
    end
  end
end
