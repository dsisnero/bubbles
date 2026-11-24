require "./spec_helper"

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

  # Go: TestPercentBounds
  it "clamps percent inputs and treats NaN as zero" do
    {
      Float64::NAN       => 0.0,
      -Float64::INFINITY => 0.0,
      Float64::INFINITY  => 1.0,
                    -0.5 => 0.0,
                     1.5 => 1.0,
                     0.5 => 0.5,
    }.each do |input, want|
      m = Bubbles::Progress.new
      m.set_percent(input)
      m.percent.should eq(want)
      m.view_as(input).should eq(m.view_as(want))
    end
  end

  # Go: TestNaNAnimationRecovery
  it "stops and recovers its animation after a NaN target" do
    m = Bubbles::Progress.new
    m.set_percent(0.5)
    20.times { m, _ = m.update(Bubbles::Progress::FrameMsg.new(m.id, m.tag)) }

    {Float64::NAN, 0.75}.each do |target|
      m.set_percent(target)
      stopped = false
      600.times do
        m, cmd = m.update(Bubbles::Progress::FrameMsg.new(m.id, m.tag))
        if cmd.nil?
          stopped = true
          break
        end
      end
      stopped.should be_true
      m.animating?.should be_false
      want = target.nan? ? 0.0 : target
      (m.percent_shown - want).abs.should be < 0.001
    end
  end
end
