# frozen_string_literal: true

class MultiTransitionFailHandlingStateMachine
  class Error < StandardError; end
  class RunError < StandardError; end

  include SimplyFSM

  state_machine :activity, fail: :on_any_fail do
    state :sleeping, initial: true
    state :running
    state :cleaning

    event :run,
          fail: ->(_event) { raise RunError, "Cannot run" },
          transitions: [{ from: :sleeping, to: :running }]

    event :clean, transitions: [
      { from: :running, to: :cleaning }
    ]

    event :sleep, transitions: [
      { from: :running, to: :sleeping },
      { when: -> { cleaning? }, to: :sleeping }
    ]
  end

  def on_any_fail(event_name)
    raise Error, "Cannot do: #{event_name}"
  end
end

RSpec.describe MultiTransitionFailHandlingStateMachine do
  describe "#sleep" do
    it "error if already sleeping" do
      expect { subject.sleep }.to raise_error(MultiTransitionFailHandlingStateMachine::Error)
    end
  end

  describe "#run" do
    it "custom error if already running" do
      subject.run
      expect { subject.run }.to raise_error(MultiTransitionFailHandlingStateMachine::RunError)
    end

    it "custom error if cleaning" do
      subject.run
      subject.clean
      expect { subject.run }.to raise_error(MultiTransitionFailHandlingStateMachine::RunError)
    end
  end

  describe "#clean" do
    it "error if sleeping" do
      expect { subject.clean }.to raise_error(MultiTransitionFailHandlingStateMachine::Error)
    end

    it "error if already cleaning" do
      subject.run
      subject.clean
      expect { subject.clean }.to raise_error(MultiTransitionFailHandlingStateMachine::Error)
    end
  end
end
