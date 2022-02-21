# frozen_string_literal: true

module SimplyFSM
  VERSION = "0.1.0"

  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    def state_machine(name, opts = {}, &block)
      fsm = StateMachine.new(name, self, fail: opts[:fail])
      fsm.instance_eval(&block)
    end
  end

  class StateMachine
    attr_reader :initial_state, :states, :events, :name, :full_name

    def initialize(name, owner_class, fail: nil)
      @owner_class = owner_class
      @name = name.to_sym
      @full_name = "#{owner_class.name}/#{name}"
      @states = []
      @events = []
      @initial_state = nil
      @fail_handler = fail

      setup_base_methods
    end

    def state(state_name, initial: false)
      unless state_name.nil? || @states.include?(state_name)
        status = state_name.to_sym
        state_machine_name = @name
        @states << status
        @initial_state = status if initial

        make_owner_method "#{state_name}?", lambda {
          send(state_machine_name) == status
        }
      end
    end

    def event(event_name, transition:, guard: nil, fail: nil, &after)
      if event_name && transition
        @events << event_name
        from = transition[:from]
        to = transition[:to]
        state_machine_name = @name
        var_name = "@#{state_machine_name}"
        may_event_name = "may_#{event_name}?"
        fail = @fail_handler if fail.nil?

        setup_may_event_method may_event_name, from, to, guard

        #
        # Setup the event method to attempt to make the state
        # transition or report failure
        make_owner_method event_name, lambda {
          if send(may_event_name)
            instance_variable_set(var_name, to)
            instance_exec(&after) if after
            return true
          end
          # unable to satisfy pre-conditions for the event
          if fail
            if fail.is_a?(String) || fail.is_a?(Symbol)
              send(fail, event_name)
            else
              instance_exec(event_name, &fail)
            end
          end
          false
        }

      end
    end

    private

    def setup_may_event_method(may_event_name, from, _to, guard)
      state_machine_name = @name
      #
      # Instead of one "may_event?" method that checks all variations
      # every time it's called, here we check the event definition and
      # define the most optimal lambda to ensure the check is as fast as
      # possible
      method_lambda = if from == :any && !guard
                        -> { true } # unguarded transition from any state
                      elsif from == :any
                        guard         # guarded transition from any state
                      elsif !guard
                        if from.is_a?(Array)
                          lambda {    # unguarded transition from choice of states
                            current = send(state_machine_name)
                            from.include?(current)
                          }
                        else
                          lambda {    # unguarded transition from one state
                            current = send(state_machine_name)
                            from == current
                          }
                        end
                      elsif from.is_a?(Array)
                        lambda {    # guarded transition from choice of states
                          current = send(state_machine_name)
                          from.include?(current) && instance_exec(&guard)
                        }
                      else
                        lambda {    # guarded transition from one state
                          current = send(state_machine_name)
                          from == current && instance_exec(&guard)
                        }
                      end
      make_owner_method may_event_name, method_lambda
    end

    def setup_base_methods
      var_name = "@#{name}"
      fsm = self
      make_owner_method @name, lambda {
                                 instance_variable_get(var_name) ||
                                   fsm.initial_state
                               }
      make_owner_method "#{@name}_states", -> { fsm.states }
      make_owner_method "#{@name}_events", -> { fsm.events }
    end

    def make_owner_method(method_name, method_definition)
      @owner_class.define_method(method_name, method_definition)
    end
  end
end
