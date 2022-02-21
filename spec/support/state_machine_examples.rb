# frozen_string_literal: true

RSpec.shared_examples "state machine basics" do |state_machine, initial_state:, states:, events:|
  describe "state machine for #{state_machine}" do
    it "initially #{initial_state}" do
      expect(subject.send(state_machine)).to eq initial_state
    end

    context "defines event methods" do
      events.each do |event|
        it event.to_s do
          expect(subject.class.method_defined?(event)).to be true
        end
      end
    end

    context "defines info methods" do
      it "#{state_machine}_states" do
        expect(subject.send("#{state_machine}_states")).to eq states
      end

      it "#{state_machine}_events" do
        expect(subject.send("#{state_machine}_events")).to eq events
      end
    end

    context "defines state methods" do
      states.each do |state|
        it "#{state}?" do
          expect(subject.class.method_defined?("#{state}?")).to be true
        end
      end
    end

    context "defines event pre-condition methods" do
      events.each do |event|
        it "may_#{event}?" do
          expect(subject.class.method_defined?("may_#{event}?")).to be true
        end
      end
    end
  end
end
