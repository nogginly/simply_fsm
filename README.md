# SimplyFSM

`simply_fsm` is a bare-necessities finite state machine data-type for use with any Ruby class. I created `simply_fsm` because I wanted the minimal FSM data type that was easy to use and did everything I would expect from a core data type.

If you need storage/persistence/Rails/etc support, I recommend the venerable [aasm](https://github.com/aasm/aasm)whose API was an inspiration for this gem.  

**Contents**
- [Installation](#installation)
- [Usage](#usage)
  - [One state machine](#one-state-machine)
  - [Multiple state machines](#multiple-state-machines)
  - [Handle failed events](#handle-failed-events)
  - [Guarding events](#guarding-events)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)
- [Code of Conduct](#code-of-conduct)

## Installation

> TODO: Not ready yet

Add this line to your application's Gemfile:

```ruby
gem 'simply_fsm'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install simply_fsm

## Usage

### One state machine

Here's a single-state example of a `Job` class (unashamedly based on [this `aasm` example](https://github.com/aasm/aasm#usage)).
 
```ruby
class Job
  include SimplyFSM

  state_machine :status do
    state :sleeping, initial: true
    state :running
    state :cleaning

    event :run, transition: { from: :sleeping, to: :running } do
      # executed when transition succeeds
    end

    event :clean, transition: { from: :running, to: :cleaning } do
      # do the cleaning since transition succeeded
    end

    event :sleep, transition: { from: [:running, :cleaning], to: :sleeping }
  end
end
```

This provides the following public methods for the class. 

```ruby
job = Job.new
job.status    # => :sleeping
job.sleeping? # => true
job.may_run?  # => true
job.run       # => true on success
job.running?  # => true
job.sleeping? # => false
job.may_run?  # => false
job.run       # => false on failure
```

### Multiple state machines

A class can define as many state machines as needed as long as each has a unique name. 

```ruby
class Player
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
```
This provides the following public methods for the class. 

| Public method for           | `motion` state machine   | `action`  state machine   |
| --------------------------- | ------------------------ | ------------------------- |
| current state               | `motion`                 | `action`                  |
| event methods               | `idle`, `walk`           | `hold`, `block`           |
| event precondition checking | `may_idle?`, `may_walk?` | `may_hold?`, `may_block?` |
| state checking              | `idling?`, `walking?`    | `ready?`, `blocking?`     |

### Handle failed events

It's possible to specify an ebent failure handler via lambda or method name either for the entire state machine or for each event. If specified, the `fail` handler is called before an event returns `false`

```ruby
class JobWithErrors
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
```

### Guarding events

It's possible guard events against additional constraints by specifying a lambda for each event which is executed in the instance of the class with the state machine. In addition to checking the allowed `from` state, the `guard`, if specified, must return `true` for the transition to occur.

```ruby
class AgilePlayer
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
```

## Development

> TODO: Not ready yet

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and sugestions are welcome. Otherwise, at this time, this project is closed for code changes and pull requests. I appreciate your understanding.

This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/nogginly/simply_fsm/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the `simply_fsm` project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/nogginly/simply_fsm/blob/main/CODE_OF_CONDUCT.md).
