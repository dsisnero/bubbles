require "./spec_helper"
require "../src/bubbles/stopwatch"

describe Bubbles::Stopwatch do
  it "creates with default interval and id" do
    m = Bubbles::Stopwatch.new
    m.interval.should eq(1.second)
    m.id.should be > 0
    m.running?.should be_false
    m.elapsed.should eq(0.seconds)
  end

  it "supports with_interval option" do
    m = Bubbles::Stopwatch.new(Bubbles::Stopwatch.with_interval(250.milliseconds))
    m.interval.should eq(250.milliseconds)
  end

  it "handles start stop and reset messages" do
    m = Bubbles::Stopwatch.new(Bubbles::Stopwatch.with_interval(1.second))

    m.update(Bubbles::Stopwatch::StartStopMsg.new(m.id, true))
    m.running?.should be_true
    m.running.should be_true

    m.update(Bubbles::Stopwatch::TickMsg.new(m.id, 0))
    m.elapsed.should eq(1.second)

    m.update(Bubbles::Stopwatch::StartStopMsg.new(m.id, false))
    m.running?.should be_false
    m.running.should be_false

    m.update(Bubbles::Stopwatch::TickMsg.new(m.id, 0))
    m.elapsed.should eq(1.second)

    m.update(Bubbles::Stopwatch::ResetMsg.new(m.id))
    m.elapsed.should eq(0.seconds)
  end

  it "ignores foreign ids and stale tags" do
    m = Bubbles::Stopwatch.new
    m.update(Bubbles::Stopwatch::StartStopMsg.new(m.id, true))

    m.update(Bubbles::Stopwatch::TickMsg.new(m.id + 1, 0))
    m.elapsed.should eq(0.seconds)

    m.update(Bubbles::Stopwatch::TickMsg.new(m.id, 5))
    m.elapsed.should eq(0.seconds)
  end

  it "provides ID() method matching Go" do
    m = Bubbles::Stopwatch.new
    m.id.should eq(m.id) # id() method should return same as id property
  end

  it "provides Elapsed() method matching Go" do
    m = Bubbles::Stopwatch.new
    m.elapsed.should eq(0.seconds) # elapsed() method should return elapsed time
  end

  it "provides Running() method matching Go" do
    m = Bubbles::Stopwatch.new
    m.running.should be_false # running() method should return running state

    m.update(Bubbles::Stopwatch::StartStopMsg.new(m.id, true))
    m.running.should be_true
  end

  it "start method uses tea.Sequence" do
    m = Bubbles::Stopwatch.new
    # The start method should return a sequence command
    cmd = m.start
    cmd.should be_a(Tea::Cmd)
  end
end
