# frozen_string_literal: true

require "simply_fsm/version"

##
# Defines the `SimplyFSM` module
module SimplyFSM
  def self.included(base)
    base.extend(ClassMethods)
  end

  def state_match?(from, current)
    return true if from == :any
    return from.include?(current) if from.is_a?(Array)

    from == current
  end

  def cannot_transition?(from, cond, current)
    (from && !state_match?(from, current)) || (cond && !instance_exec(&cond))
  end

  ##
  # Defines the constructor for defining a state machine
  module ClassMethods
    ##
    # Declare a state machine called +name+ which can then be defined
    # by a DSL defined by the methods of `StateMachine`, with the following +opts+:
    # - an optional +fail+ lambda that is called when any event fails to transition)
    def state_machine(name, opts = {}, &block)
      fsm = StateMachine.new(name, self, fail: opts[:fail])
      fsm.instance_eval(&block)
    end
  end

  ##
  # The DSL for defining a state machine
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

    ##
    # Declare a supported +state_name+, and optionally specify one as the +initial+ state.
    def state(state_name, initial: false)
      return if state_name.nil? || @states.include?(state_name)

      status = state_name.to_sym
      state_machine_name = @name
      @states << status
      @initial_state = status if initial

      make_owner_method "#{state_name}?", lambda {
        send(state_machine_name) == status
      }
    end

    ##
    # Define an event by +event_name+
    #
    # - which +transitions+ as a hash with a +from+ state or array of states and the +to+ state,
    # - an optional +guard+ lambda which must return true for the transition to occur,
    # - an optional +fail+ lambda that is called when the transition fails (overrides top-level fail handler), and
    # - an optional do block that is called +after+ the transition succeeds
    def event(event_name, transitions:, guard: nil, fail: nil, &after)
      return unless event_exists?(event_name) && transitions

      @events << event_name
      may_event_name = "may_#{event_name}?"

      if transitions.is_a?(Array)
        setup_multi_transition_may_event_method transitions: transitions, guard: guard,
                                                may_event_name: may_event_name
        setup_multi_transition_event_method event_name,
                                            transitions: transitions, guard: guard,
                                            var_name: "@#{@name}", fail: fail || @fail_handler
        return
      end

      to = transitions[:to]
      setup_may_event_method may_event_name, transitions[:from] || :any, transitions[:when], guard
      setup_event_method event_name, var_name: "@#{@name}",
                                     may_event_name: may_event_name, to: to,
                                     fail: fail || @fail_handler, &after
    end

    private

    def setup_multi_transition_may_event_method(transitions:, guard:, may_event_name:)
      state_machine_name = @name

      make_owner_method may_event_name, lambda {
        if !guard || instance_exec(&guard)
          current = send(state_machine_name)
          # Check each transition, and first one that succeeds ends the scan
          transitions.each do |t|
            next if cannot_transition?(t[:from], t[:when], current)

            return true
          end
        end
        false
      }
    end

    def setup_fail_lambda_for(fail)
      return unless fail

      if fail.is_a?(String) || fail.is_a?(Symbol)
        ->(event_name) { send(fail, event_name) }
      else
        ->(event_name) { instance_exec(event_name, &fail) }
      end
    end

    def setup_multi_transition_event_method(event_name, transitions:, guard:, var_name:, fail:)
      state_machine_name = @name
      fail_lambda = setup_fail_lambda_for(fail)
      make_owner_method event_name, lambda {
        if !guard || instance_exec(&guard)
          current = send(state_machine_name)
          # Check each transition, and first one that succeeds ends the scan
          transitions.each do |t|
            next if cannot_transition?(t[:from], t[:when], current)

            instance_variable_set(var_name, t[:to])
            return true
          end
        end
        instance_exec(event_name, &fail_lambda) if fail_lambda
        false
      }
    end

    def event_exists?(event_name)
      event_name && !@events.include?(event_name)
    end

    def setup_event_method(event_name, var_name:, may_event_name:, to:, fail:, &after)
      fail_lambda = setup_fail_lambda_for(fail)
      method_lambda = lambda {
        if send(may_event_name)
          instance_variable_set(var_name, to)
          instance_exec(&after) if after
          return true
        end
        instance_exec(event_name, &fail_lambda) if fail_lambda
        false
      }
      make_owner_method event_name, method_lambda
    end

    def setup_may_event_method(may_event_name, from, cond, guard)
      state_machine_name = @name
      #
      # Instead of one "may_event?" method that checks all variations every time it's called, here we check
      # the event definition and define the most optimal lambda to ensure the check is as fast as possible
      method_lambda = if from == :any
                        from_any_may_event_lambda(guard, cond, state_machine_name)
                      else
                        guarded_or_conditional_may_event_lambda(from, guard, cond, state_machine_name)
                      end
      make_owner_method may_event_name, method_lambda
    end

    def from_any_may_event_lambda(guard, cond, _state_machine_name)
      if !guard && !cond
        -> { true } # unguarded transition from any state
      elsif !cond
        guard # guarded transition from any state
      elsif !guard
        cond # conditional unguarded transition from any state
      else
        -> { instance_exec(&guard) && instance_exec(&cond) }
      end
    end

    def guarded_or_conditional_may_event_lambda(from, guard, cond, state_machine_name)
      if !guard && !cond
        guardless_may_event_lambda(from, state_machine_name)
      elsif !cond
        guarded_may_event_lambda(from, guard, state_machine_name)
      elsif !guard
        guarded_may_event_lambda(from, cond, state_machine_name)
      else
        guarded_and_conditional_may_event_lambda(from, guard, cond, state_machine_name)
      end
    end

    def guarded_may_event_lambda(from, guard, state_machine_name)
      if from.is_a?(Array)
        lambda { # guarded transition from choice of states
          current = send(state_machine_name)
          from.include?(current) && instance_exec(&guard)
        }
      else
        lambda { # guarded transition from one state
          current = send(state_machine_name)
          from == current && instance_exec(&guard)
        }
      end
    end

    def guarded_and_conditional_may_event_lambda(from, guard, cond, state_machine_name)
      if from.is_a?(Array)
        lambda { # guarded transition from choice of states
          current = send(state_machine_name)
          from.include?(current) && instance_exec(&guard) && instance_exec(&cond)
        }
      else
        lambda { # guarded transition from one state
          current = send(state_machine_name)
          from == current && instance_exec(&guard) && instance_exec(&cond)
        }
      end
    end

    def guardless_may_event_lambda(from, state_machine_name)
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
