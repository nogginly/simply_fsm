# frozen_string_literal: true

#
# Include *SimplyFSM* in a class to be able to defined state machines.
#
module SimplyFSM
  #
  # Provides a +state_machine+ for the including class.
  def self.included(base)
    base.extend(ClassMethods)
  end

  #
  # Defines the constructor for defining a state machine
  module ClassMethods
    #
    # Declare a state machine called +name+ which can then be defined
    # by a DSL defined by the methods of *StateMachine*.
    #
    # @param [String] name of the state machine.
    # @param [Hash] opts to specify options such as:
    #   - +fail+ lambda that is called with the event name when any event fails to transition
    #
    def state_machine(name, opts = {}, &block)
      fsm = StateMachine.new(name, self, fail: opts[:fail])
      fsm.instance_eval(&block)
    end
  end

  ##
  # The DSL for defining a state machine. These methods are used within the declaration of a +state_machine+.
  #
  # @attr_reader [String] initial_state The initial state of the state machine
  # @attr_reader [Array] states All the states of the state machine
  # @attr_reader [Array] events All the events of the state machine
  # @attr_reader [String] name
  # @attr_reader [String] full_name The name of the owning class combined with the state machine's name
  #
  class StateMachine
    attr_reader :initial_state, :states, :events, :name, :full_name

    #
    # @!visibility private
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

    #
    # Declare a supported +state_name+, and optionally specify one as the +initial+ state.
    #
    # @param [String] state_name
    # @param [Boolean] initial to indicate if this is the initial state of the state machine
    #
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
    # @param [String] event_name
    # @param [Hash,Array] transitions either one (Hash) or many (Array of Hashes) transitions +from+ one state +to+ another state.
    # @param [Lambda] guard if specified must return +true+ before any transitions are attempted
    # @param [Lambda] fail called with event name if specified when all the attempted transitions fail
    # @yield when the transition attempt succeeds.
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
        fail
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

  private

  def state_match?(from, current)
    return true if from == :any
    return from.include?(current) if from.is_a?(Array)

    from == current
  end

  def cannot_transition?(from, cond, current)
    (from && !state_match?(from, current)) || (cond && !instance_exec(&cond))
  end
end
