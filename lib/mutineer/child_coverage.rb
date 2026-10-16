# frozen_string_literal: true

module Mutineer
  # Lets a test helper start Coverage in a forked mutant child (#248).
  #
  # Once the coverage map is built, the parent suspends Coverage so mutant
  # children do not pay for it (#228). A suspended Coverage reports
  # `running? == false`, so a test helper that starts it when it is off
  # (SimpleCov's `SimpleCov.start`) calls `Coverage.start`, which raises
  # "coverage measurement is already setup" while Coverage is suspended. Every
  # mutant then errors before a test runs.
  #
  # In the child, `Coverage.start` and `Coverage.setup` first stop the
  # suspended Coverage, then run as usual. Stopping builds and drops the whole
  # result, which walks the heap, so only a child whose helper starts Coverage
  # pays for it. Only files loaded after that start are measured. The parent's
  # Coverage is untouched.
  #
  # Stdlib-only, so the app-side daemon can load it.
  module ChildCoverage
    # Prepended to Coverage's singleton class in the child: stops a suspended
    # Coverage before a start or setup.
    module StopBeforeStart
      # Stops a suspended Coverage, then sets it up.
      #
      # @return [nil]
      def setup(...)
        result(stop: true, clear: true) if state == :suspended
        super
      end

      # Stops a suspended Coverage, then starts it.
      #
      # @return [nil]
      def start(...)
        result(stop: true, clear: true) if state == :suspended
        super
      end
    end

    # Makes a later `Coverage.start` or `Coverage.setup` work when Coverage is
    # suspended. A running or idle Coverage is left alone.
    #
    # Call it only in a forked child, before any test loads.
    #
    # @return [void]
    def self.allow_start
      return unless defined?(::Coverage) && ::Coverage.state == :suspended

      ::Coverage.singleton_class.prepend(StopBeforeStart)
    end
  end
end
