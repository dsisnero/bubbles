require "./spec_helper"
require "../src/bubbles/timer"

describe Bubbles::Timer do
  it "creates with default settings" do
    m = Bubbles::Timer.new(10.seconds)
    m.interval.should eq(1.second)
    m.timeout.should eq(10.seconds)
    m.id.should be > 0
    m.running?.should be_true
    m.timedout?.should be_false
  end

  it "supports with_interval option" do
    m = Bubbles::Timer.new(10.seconds, Bubbles::Timer.with_interval(200.milliseconds))
    m.interval.should eq(200.milliseconds)
  end

  it "ticks down and times out" do
    m = Bubbles::Timer.new(2.seconds, Bubbles::Timer.with_interval(1.second))

    m.update(Bubbles::Timer::TickMsg.new(m.id, false, 0))
    m.timeout.should eq(1.second)
    m.timedout?.should be_false

    m.update(Bubbles::Timer::TickMsg.new(m.id, false, m.tag))
    m.timeout.should eq(0.seconds)
    m.timedout?.should be_true
    m.running?.should be_false
  end

  it "start stop toggle" do
    m = Bubbles::Timer.new(5.seconds)

    m.update(Bubbles::Timer::StartStopMsg.new(m.id, false))
    m.running?.should be_false

    m.update(Bubbles::Timer::StartStopMsg.new(m.id, true))
    m.running?.should be_true

    toggle_cmd = m.toggle
    toggle_msg = toggle_cmd.not_nil!.call
    toggle_msg.should be_a(Bubbles::Timer::StartStopMsg)
  end

  it "ignores foreign timer messages and stale tags" do
    m = Bubbles::Timer.new(5.seconds)
    m.update(Bubbles::Timer::TickMsg.new(m.id + 1, false, 0))
    m.timeout.should eq(5.seconds)

    m.update(Bubbles::Timer::TickMsg.new(m.id, false, 99))
    m.timeout.should eq(5.seconds)
  end
end
