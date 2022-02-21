# frozen_string_literal: true

class TwoStateMachines
  include SimplyFSM

  state_machine :motion do
    state :idling, initial: true
    state :walking

    event :idle, transition: { from: :any, to: :idling }
    event :walk, transition: { from: :idling, to: :walking }
  end

  state_machine :action do
    state :ready, initial: true
    state :blocking

    event :hold, transition: { from: :any, to: :ready }
    event :block, transition: { from: :any, to: :blocking }
  end
end

RSpec.describe TwoStateMachines do
  include_examples "state machine basics", :motion,
                   initial_state: :idling,
                   states: %i[idling walking],
                   events: %i[idle walk]

  include_examples "state machine basics", :action,
                   initial_state: :ready,
                   states: %i[ready blocking],
                   events: %i[hold block]
end
