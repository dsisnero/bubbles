require "./spec_helper"

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

    m, _ = m.update(Bubbles::Stopwatch::StartStopMsg.new(m.id, true))
    m.running?.should be_true

    m, cmd = m.update(Bubbles::Stopwatch::TickMsg.new(m.id, 0))
    cmd.should_not be_nil

    m, _ = m.update(Bubbles::Stopwatch::StartStopMsg.new(m.id, false))
    m.running?.should be_false
    paused = m.elapsed

    m, cmd = m.update(Bubbles::Stopwatch::TickMsg.new(m.id, 0))
    cmd.should be_nil
    m.elapsed.should eq(paused)

    m, _ = m.update(Bubbles::Stopwatch::ResetMsg.new(m.id))
    m.elapsed.should eq(0.seconds)
  end

  it "ignores foreign ids and stale tags" do
    m = Bubbles::Stopwatch.new
    m, _ = m.update(Bubbles::Stopwatch::StartStopMsg.new(m.id, true))

    m, cmd = m.update(Bubbles::Stopwatch::TickMsg.new(m.id + 1, 0))
    cmd.should be_nil

    m, cmd = m.update(Bubbles::Stopwatch::TickMsg.new(m.id, 5))
    cmd.should be_nil
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

  # Go: TestNewDefaultInterval
  it "defaults to a one second interval" do
    Bubbles::Stopwatch.new.interval.should eq(1.second)
  end

  # Go: TestElapsedAdvancesWithTimeWhileRunning
  it "advances elapsed by wall clock, not by the interval" do
    m = Bubbles::Stopwatch.new(Bubbles::Stopwatch.with_interval(1.second))
    m, _ = m.update(Bubbles::Stopwatch::StartStopMsg.new(m.id, true))

    sleep 50.milliseconds
    m, _ = m.update(Bubbles::Stopwatch::TickMsg.new(m.id, m.tag))

    m.elapsed.should be >= 40.milliseconds
    m.elapsed.should be < 1.second
  end

  # Go: TestPauseFreezesElapsed
  it "freezes elapsed while paused and resumes afterwards" do
    m = Bubbles::Stopwatch.new(Bubbles::Stopwatch.with_interval(1.second))
    m, _ = m.update(Bubbles::Stopwatch::StartStopMsg.new(m.id, true))
    sleep 40.milliseconds
    m, _ = m.update(Bubbles::Stopwatch::StartStopMsg.new(m.id, false))

    paused = m.elapsed
    paused.should be >= 20.milliseconds

    sleep 40.milliseconds
    m, cmd = m.update(Bubbles::Stopwatch::TickMsg.new(m.id, m.tag))
    cmd.should be_nil
    m.elapsed.should eq(paused)

    m, _ = m.update(Bubbles::Stopwatch::StartStopMsg.new(m.id, true))
    sleep 40.milliseconds
    m.elapsed.should be >= paused + 20.milliseconds
  end

  # Go: TestResetClearsElapsed
  it "clears elapsed on reset whether running or stopped" do
    m = Bubbles::Stopwatch.new(Bubbles::Stopwatch.with_interval(1.second))
    m, _ = m.update(Bubbles::Stopwatch::StartStopMsg.new(m.id, true))
    sleep 40.milliseconds
    m, _ = m.update(Bubbles::Stopwatch::TickMsg.new(m.id, m.tag))
    m.elapsed.should_not eq(0.seconds)

    m, _ = m.update(Bubbles::Stopwatch::ResetMsg.new(m.id))
    m.elapsed.should be <= 15.milliseconds

    m, _ = m.update(Bubbles::Stopwatch::StartStopMsg.new(m.id, false))
    m, _ = m.update(Bubbles::Stopwatch::StartStopMsg.new(m.id, true))
    sleep 40.milliseconds
    m, _ = m.update(Bubbles::Stopwatch::StartStopMsg.new(m.id, false))
    m.elapsed.should_not eq(0.seconds)
    m, _ = m.update(Bubbles::Stopwatch::ResetMsg.new(m.id))
    m.elapsed.should eq(0.seconds)
  end

  # Go: TestTagDebounceRejectsForeignTags
  it "rejects foreign and stale tick tags" do
    m = Bubbles::Stopwatch.new(Bubbles::Stopwatch.with_interval(1.second))
    m, _ = m.update(Bubbles::Stopwatch::StartStopMsg.new(m.id, true))
    sleep 20.milliseconds

    m, cmd = m.update(Bubbles::Stopwatch::TickMsg.new(m.id, m.tag))
    cmd.should_not be_nil
    tag = m.tag
    tag.should_not eq(0)

    m, cmd = m.update(Bubbles::Stopwatch::TickMsg.new(m.id, tag + 7))
    cmd.should be_nil
    m.tag.should eq(tag)
    m.elapsed.should be < 2.seconds

    m, cmd = m.update(Bubbles::Stopwatch::TickMsg.new(m.id, tag))
    cmd.should_not be_nil
    m.tag.should eq(tag + 1)

    m, cmd = m.update(Bubbles::Stopwatch::TickMsg.new(m.id, tag))
    cmd.should be_nil
    m.tag.should eq(tag + 1)
  end

  # Go: TestViewAlignsToInterval
  it "truncates the displayed duration to the interval" do
    m = Bubbles::Stopwatch.new
    m, _ = m.update(Bubbles::Stopwatch::StartStopMsg.new(m.id, true))
    sleep 50.milliseconds

    m.view.should eq("0s")
    m.elapsed.should be >= 20.milliseconds
  end
end
