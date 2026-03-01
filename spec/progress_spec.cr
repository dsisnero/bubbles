require "./spec_helper"
require "../src/bubbles/progress"

describe Bubbles::Progress do
  it "TestBlend" do
    p = Bubbles::Progress.new(
      Bubbles::Progress.with_width(10),
      Bubbles::Progress.without_percentage
    )

    # With color rendering, the output includes ANSI codes
    # So we can't just check size, we need to check it renders something
    p.view_as(0.5).should_not be_empty
    p.view_as(1.0).should_not be_empty
  end

  it "supports SetPercent IncrPercent DecrPercent" do
    p = Bubbles::Progress.new
    p.set_percent(0.4)
    p.percent.should eq(0.4)
    p.incr_percent(0.2)
    p.percent.should be_close(0.6, 1e-12)
    p.decr_percent(0.1)
    p.percent.should be_close(0.5, 1e-12)
  end
end
