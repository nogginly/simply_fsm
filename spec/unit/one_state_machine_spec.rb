# frozen_string_literal: true

class OneStateMachine
  include SimplyFSM

  state_machine :activity do
    state :sleeping, initial: true
    state :running
    state :cleaning

    event :run, transition: { from: :sleeping, to: :running }
    event :clean, transition: { from: :running, to: :cleaning }
    event :sleep, transition: { from: %i[running cleaning], to: :sleeping }
  end
end

RSpec.describe OneStateMachine do
  include_examples "state machine basics", :activity,
                   initial_state: :sleeping,
                   states: %i[sleeping running cleaning],
                   events: %i[run clean sleep]

  describe "#sleep" do
    it "fails if already sleeping" do
      expect(subject.may_sleep?).to be false
      expect(subject.sleep).to be false
    end
    it "succeeds if running" do
      subject.run
      expect(subject.may_sleep?).to be true
      expect(subject.sleep).to be true
    end
    it "succeeds if cleaning" do
      subject.run
      subject.clean
      expect(subject.may_sleep?).to be true
      expect(subject.sleep).to be true
    end
  end

  describe "#run" do
    it "succeeds if sleeping" do
      expect(subject.may_run?).to be true
      expect(subject.run).to be true
    end

    it "fails if already running" do
      subject.run
      expect(subject.may_run?).to be false
      expect(subject.run).to be false
    end

    it "fails if cleaning" do
      subject.run
      subject.clean
      expect(subject.may_run?).to be false
      expect(subject.run).to be false
    end
  end

  describe "#clean" do
    it "succeeds if running" do
      subject.run
      expect(subject.may_clean?).to be true
      expect(subject.clean).to be true
    end

    it "fails if sleeping" do
      expect(subject.may_clean?).to be false
      expect(subject.clean).to be false
    end

    it "fails if already cleaning" do
      subject.run
      subject.clean
      expect(subject.may_clean?).to be false
      expect(subject.clean).to be false
    end
  end
end
