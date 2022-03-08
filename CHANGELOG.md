## [Unreleased]

- None right now

## [0.2.2] - 2022-03-08

- Call `fail` lambda without wrapping it in a lambda

## [0.2.1] - 2022-03-05

- Fixed bug where named fail handlers were not called properly for multi-transition events.

## [0.2.0] - 2022-03-01

- *Breaks API* (sorry!)
  - When declaring events in a state machine, use `transitions:` (as in "transitions from X to Y") instead of `transition:`
- Added support for multiple transitions per event

## [0.1.2] - 2022-02-28

- Cleaned up source with smaller clearer methods
- Added `rdoc` support, include `rake rdoc` task

## [0.1.1] - 2022-02-21

- Separated version file, fixed URLs in Gem spec, added badge to README

## [0.1.0] - 2022-02-21

- Initial release supports finite state machine with event guards and failure handling 
