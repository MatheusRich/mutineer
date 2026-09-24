# frozen_string_literal: true

require "stringio"

module Mutineer
  # Raised when the target project asks for a framework whose gem isn't present.
  # rspec is NOT a Mutineer dependency — it must come from the project's bundle.
  class FrameworkUnavailable < StandardError; end

  module TestRunners
    # Child-process-only RSpec runner.
    #
    # Mirrors MinitestIntegration's contract: run the given spec files and
    # return 0 (all passed) or 1 (any failure).
    module RSpec
      # Runs the given RSpec files.
      #
      # @param spec_files [String, Array<String>] one file or many files.
      # @return [Integer] 0 on success, 1 on failure.
      def self.run(spec_files)
        require_rspec!

        ::RSpec::Core::Runner.disable_autorun!
        ::RSpec.reset

        sink = StringIO.new
        # Reopen fds 1 and 2 through STDOUT/STDERR instead of swapping in a
        # StringIO: a spec that calls `$stdout.reopen` (e.g.
        # to_stdout_from_any_process) needs a real IO, and $stdout itself may
        # already be a StringIO that a spec left.
        orig_out = $stdout
        orig_err = $stderr
        saved_out = STDOUT.dup
        saved_err = STDERR.dup
        begin
          STDOUT.reopen(File::NULL)
          STDERR.reopen(File::NULL)
          $stdout = STDOUT
          $stderr = STDERR
          status = ::RSpec::Core::Runner.run(["--no-color", *Array(spec_files)], sink, sink)
        ensure
          STDOUT.reopen(saved_out)
          STDERR.reopen(saved_err)
          saved_out.close
          saved_err.close
          $stdout = orig_out
          $stderr = orig_err
        end

        status.zero? ? 0 : 1
      end

      # Requires rspec-core from the project under test.
      #
      # @api private
      def self.require_rspec!
        require "rspec/core"
      rescue LoadError
        raise Mutineer::FrameworkUnavailable,
              "framework 'rspec' requested but rspec is not available; " \
              "add rspec to the project under test (its bundle), then retry"
      end
    end
  end
end
