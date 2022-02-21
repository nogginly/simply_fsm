# frozen_string_literal: true

class GuardingEvents
  class LeapError < StandardError; end

  include SimplyFSM

  state_machine :motion do
    state :idling, initial: true
    state :walking
    state :running

    event :idle, transition: { from: :any, to: :idling }
    event :walk, transition: { from: :any, to: :walking }
    event :run, transition: { from: :any, to: :running }
  end

  state_machine :action do
    state :ready, initial: true
    state :jumping
    state :leaping

    event :hold, transition: { from: :any, to: :ready }
    event :jump,
          guard: -> { !running? },
          transition: { from: :ready, to: :jumping }
    event :leap,
          guard: -> { running? },
          fail: ->(_event) { raise LeapError, "Cannot leap" },
          transition: { from: :ready, to: :leaping }
  end
end

RSpec.describe GuardingEvents do
  describe "#jump" do
    it "guard fails if motion is running" do
      subject.run
      expect(subject.may_jump?).to be false
      expect(subject.jump).to be false
    end
  end

  describe "#leap" do
    it "guard raises error if motion is not running" do
      subject.walk
      expect(subject.may_leap?).to be false
      expect { subject.leap }.to raise_error(GuardingEvents::LeapError)
    end
  end
end
