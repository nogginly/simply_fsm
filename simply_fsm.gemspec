# frozen_string_literal: true

require_relative "lib/simply_fsm/version"

Gem::Specification.new do |spec|
  spec.name = "simply_fsm"
  spec.version = SimplyFSM::VERSION
  spec.authors = ["nogginly"]
  spec.email = ["nogginly@icloud.com"]

  spec.summary = "Simple finite state mechine (FSM) data-type mixin for Ruby objects."
  spec.description = "Use it to setup one or more FSMs in any Ruby object."
  spec.homepage = "https://github.com/nogginly/simply_fsm#simplyfsm"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.7.0"
  spec.date = Time.now

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/nogginly/simply_fsm"
  spec.metadata["changelog_uri"] = "https://github.com/nogginly/simply_fsm/blob/main/CHANGELOG.md"

  spec.files         = `git ls-files`.split("\n")
  spec.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  spec.require_paths = ["lib"]

  # no deployment dependencies

  # development
  spec.add_development_dependency "rdoc"
  spec.add_development_dependency "yard"
  spec.add_development_dependency "rspec", "~> 3.0"
end
