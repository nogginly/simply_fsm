# frozen_string_literal: true

class FailHandlingStateMachine
  class Error < StandardError; end
  class RunError < StandardError; end

  include SimplyFSM

  state_machine :activity, fail: :on_any_fail do
    state :sleeping, initial: true
    state :running
    state :cleaning

    event :sleep, transition: { from: %i[running cleaning], to: :sleeping }
    event :clean, transition: { from: :running, to: :cleaning }
    event :run,
          fail: ->(_event) { raise RunError, "Cannot run" },
          transition: { from: :sleeping, to: :running }
  end

  def on_any_fail(event_name)
    raise Error, "Cannot do: #{event_name}"
  end
end

RSpec.describe FailHandlingStateMachine do
  describe "#sleep" do
    it "error if already sleeping" do
      expect { subject.sleep }.to raise_error(FailHandlingStateMachine::Error)
    end
  end

  describe "#run" do
    it "custom error if already running" do
      subject.run
      expect { subject.run }.to raise_error(FailHandlingStateMachine::RunError)
    end

    it "custom error if cleaning" do
      subject.run
      subject.clean
      expect { subject.run }.to raise_error(FailHandlingStateMachine::RunError)
    end
  end

  describe "#clean" do
    it "error if sleeping" do
      expect { subject.clean }.to raise_error(FailHandlingStateMachine::Error)
    end

    it "error if already cleaning" do
      subject.run
      subject.clean
      expect { subject.clean }.to raise_error(FailHandlingStateMachine::Error)
    end
  end
end
