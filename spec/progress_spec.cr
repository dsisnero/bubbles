require "./spec_helper"
require "../src/bubbles/progress"

describe Bubbles::Progress do
  it "TestBlend" do
    p = Bubbles::Progress.new(
      Bubbles::Progress.with_width(10),
      Bubbles::Progress.without_percentage
    )

    p.view_as(0.5).size.should eq(10)
    p.view_as(1.0).count(Bubbles::Progress::DefaultEmptyCharBlock).should eq(0)
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
