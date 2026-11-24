require "./spec_helper"

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

  # Go: TestDoubleStartDoesNotSpeedUpTimer
  it "does not spawn a second ticker on a duplicate start" do
    m = Bubbles::Timer.new(5.seconds, Bubbles::Timer.with_interval(100.milliseconds))
    m.running = false

    cmd1 = m.start
    cmd1.should_not be_nil
    msg1 = cmd1.not_nil!.call.not_nil!.as(Bubbles::Timer::StartStopMsg)
    m, cmd = m.update(msg1)
    cmd.should_not be_nil

    cmd2 = m.start
    cmd2.should_not be_nil
    msg2 = cmd2.not_nil!.call.not_nil!.as(Bubbles::Timer::StartStopMsg)
    _, cmd = m.update(msg2)
    cmd.should be_nil
  end

  # Go: TestDoubleStopDoesNotCauseIssues
  it "treats a duplicate stop as a no-op" do
    m = Bubbles::Timer.new(5.seconds, Bubbles::Timer.with_interval(100.milliseconds))
    m.running = true

    cmd1 = m.stop
    cmd1.should_not be_nil
    m, _ = m.update(cmd1.not_nil!.call.not_nil!.as(Bubbles::Timer::StartStopMsg))
    m.running?.should be_false

    cmd2 = m.stop
    cmd2.should_not be_nil
    _, cmd = m.update(cmd2.not_nil!.call.not_nil!.as(Bubbles::Timer::StartStopMsg))
    cmd.should be_nil
  end

  # Go: TestDuplicateTickStreamDoesNotPermanentlyDoubleSpeed
  it "debounces a duplicate tick stream after one overshoot" do
    m = Bubbles::Timer.new(10.seconds, Bubbles::Timer.with_interval(1.millisecond))
    cmd_a = m.init
    cmd_b = m.init
    cmd_a.should_not be_nil
    cmd_b.should_not be_nil

    initial_timeout = m.timeout
    interval = m.interval

    20.times do
      if cmd_a
        msg = cmd_a.not_nil!.call.not_nil!.as(Bubbles::Timer::TickMsg)
        m, cmd_a = m.update(msg)
      end
      if cmd_b
        msg = cmd_b.not_nil!.call.not_nil!.as(Bubbles::Timer::TickMsg)
        m, cmd_b = m.update(msg)
      end
    end

    (initial_timeout - m.timeout).should eq(interval * 21)
  end

  # Go: TestIDReturnsCorrectID
  it "gives each timer a unique id" do
    m1 = Bubbles::Timer.new(5.seconds)
    m2 = Bubbles::Timer.new(5.seconds)
    m1.id.should_not eq(m2.id)
  end

  # Go: TestInitStartsTimer
  it "returns a tick command from init" do
    Bubbles::Timer.new(5.seconds, Bubbles::Timer.with_interval(100.milliseconds)).init.should_not be_nil
  end

  # Go: TestRunningReturnsFalseWhenTimedOut
  it "is not running once timed out" do
    Bubbles::Timer.new(0.seconds).running?.should be_false
  end

  # Go: TestStartReturnsNilWhenTimedOut
  it "cannot be started after timing out" do
    m = Bubbles::Timer.new(0.seconds)
    m.timedout?.should be_true
    m.start.should be_nil
  end

  # Go: TestStartStopMsgFromDifferentTimerIsIgnored
  it "ignores start/stop messages from another timer" do
    m = Bubbles::Timer.new(5.seconds)
    m.running = false
    m, cmd = m.update(Bubbles::Timer::StartStopMsg.new(99999, true))
    m.running?.should be_false
    cmd.should be_nil
  end

  # Go: TestTagPreventsStaleTicks
  it "ignores stale ticks" do
    m = Bubbles::Timer.new(5.seconds, Bubbles::Timer.with_interval(1.second))
    m.tag = 5
    timeout = m.timeout
    m, cmd = m.update(Bubbles::Timer::TickMsg.new(m.id, false, 3))
    m.timeout.should eq(timeout)
    cmd.should be_nil
  end

  # Go: TestTickMsgFromDifferentTimerIsIgnored
  it "ignores ticks from another timer" do
    m = Bubbles::Timer.new(5.seconds, Bubbles::Timer.with_interval(1.second))
    timeout = m.timeout
    m, _ = m.update(Bubbles::Timer::TickMsg.new(99999, false, 0))
    m.timeout.should eq(timeout)
  end

  # Go: TestTickMsgHandling
  it "decrements the timeout on a tick" do
    m = Bubbles::Timer.new(5.seconds, Bubbles::Timer.with_interval(1.second))
    m, cmd = m.update(Bubbles::Timer::TickMsg.new(m.id, false, 0))
    m.timeout.should eq(4.seconds)
    cmd.should_not be_nil
  end

  # Go: TestTimeoutMsgSentOnLastTick
  it "emits a timeout command on the final tick" do
    m = Bubbles::Timer.new(1.second, Bubbles::Timer.with_interval(1.second))
    m, cmd = m.update(Bubbles::Timer::TickMsg.new(m.id, true, 0))
    m.timedout?.should be_true
    m.running?.should be_false
    cmd.should_not be_nil
  end

  # Go: TestToggleBehavior
  it "toggles between running and stopped" do
    m = Bubbles::Timer.new(5.seconds, Bubbles::Timer.with_interval(100.milliseconds))
    m.running?.should be_true

    cmd = m.toggle
    cmd.should_not be_nil
    msg = cmd.not_nil!.call.not_nil!.as(Bubbles::Timer::StartStopMsg)
    msg.running.should be_false
    m, _ = m.update(msg)
    m.running?.should be_false

    cmd = m.toggle
    cmd.should_not be_nil
    msg = cmd.not_nil!.call.not_nil!.as(Bubbles::Timer::StartStopMsg)
    msg.running.should be_true
  end

  # Go: TestUpdateHandlesStartStopMsg
  it "only ticks when the running state actually changes" do
    m = Bubbles::Timer.new(5.seconds, Bubbles::Timer.with_interval(100.milliseconds))
    m.running = false

    m, cmd = m.update(Bubbles::Timer::StartStopMsg.new(m.id, true))
    m.running?.should be_true
    cmd.should_not be_nil

    _, cmd = m.update(Bubbles::Timer::StartStopMsg.new(m.id, true))
    cmd.should be_nil
  end

  # Go: TestViewReturnsTimeoutString
  it "renders the remaining timeout" do
    Bubbles::Timer.new(5.seconds).view.should eq("5s")
  end
end
