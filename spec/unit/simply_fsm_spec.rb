# frozen_string_literal: true

class UsingFSM
  include SimplyFSM
end

RSpec.describe SimplyFSM do
  it "has a version number" do
    expect(SimplyFSM::VERSION).not_to be nil
  end

  describe "when included" do
    it "sets up state machine constructor" do
      expect(UsingFSM.respond_to?(:state_machine)).not_to be nil
    end
  end
end
