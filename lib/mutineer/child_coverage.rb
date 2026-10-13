# frozen_string_literal: true

module Mutineer
  # Leaves Coverage stopped, not suspended, in a forked mutant child (#248).
  #
  # Once the coverage map is built, the parent suspends Coverage so mutant
  # children do not pay for it (#228). A suspended Coverage reports
  # `running? == false`, so a test helper that starts it when it is off
  # (SimpleCov's `SimpleCov.start`) calls `Coverage.start`, which raises
  # "coverage measurement is already setup" while Coverage is suspended. Every
  # mutant then errors before a test runs.
  #
  # Stopping it in the child lets such a helper start Coverage again. Only files
  # loaded after that start are measured, so the boot-loaded app stays
  # unmeasured. The parent's Coverage is untouched.
  #
  # Stdlib-only, so the app-side daemon can load it.
  module ChildCoverage
    # Stops a suspended Coverage. A running or idle Coverage is left alone.
    #
    # Call it only in a forked child, before any test loads.
    #
    # @return [void]
    def self.release
      return unless defined?(::Coverage) && ::Coverage.state == :suspended

      ::Coverage.result(stop: true, clear: true)
    end
  end
end
