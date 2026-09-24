# frozen_string_literal: true

module Mutineer
  # Child-process-only: loads a test file in the current process and runs it
  # programmatically, returning an exit status integer (0 = all passed,
  # 1 = any failure/error).
  #
  # Never call this in the parent — it manipulates global Minitest state
  # (autorun, runnables) that only makes sense in a throwaway forked child.
  #
  # A missing minitest is rescued as FrameworkUnavailable (Isolation.run
  # still turns that raise into exit 2). There is no rescue around the
  # suite run itself: Isolation.run's fork block is the single exception
  # boundary for unexpected errors. Swallowing those here would create a
  # second exit-2 path and break this method's 0/1 return contract.
  class MinitestIntegration
    # Tested via runner_test.rb, not in isolation — a direct unit test
    # would require forking and duplicate isolation_test's coverage.
    #
    # `test_files` is one path or an Array of paths (coverage selection
    # passes the covering subset); each is loaded before the single
    # Minitest.run.
    #
    # @param test_files [String, Array<String>] one file or many files.
    # @return [Integer] 0 on success, 1 on failure.
    def self.run(test_files)
      begin
        require "minitest"
      rescue LoadError
        raise Mutineer::FrameworkUnavailable,
              "minitest is not available — add minitest to the project under test, " \
              "or use --framework rspec"
      end

      # minitest is required LAZILY (never at load time) so Mutineer keeps
      # zero runtime gem deps and loads fine in an rspec-only project; a missing
      # minitest raises a clear Mutineer error rather than a LoadError backtrace.

      # Neutralise autorun so a test file's `require "minitest/autorun"`
      # registers no at_exit hook.
      def Minitest.autorun; end # rubocop:disable Lint/NestedMethodDefinition

      # Drop runnables inherited from the parent suite (this is the child's
      # private copy — the parent is unaffected) so only the target test runs.
      Minitest::Runnable.reset
      # Saved before the test files load: a file may reassign $stdout.
      orig_stdout = $stdout
      Array(test_files).each { |f| load f }

      # Silence the child's test output; the parent only cares about pass/fail.
      # Reopen fd 1 through STDOUT instead of swapping in a StringIO: a test
      # that calls `$stdout.reopen` (e.g. capture_subprocess_io) needs a real
      # IO, and $stdout itself may already be a StringIO that a test left.
      saved_fd = STDOUT.dup
      begin
        STDOUT.reopen(File::NULL)
        $stdout = STDOUT
        passed = Minitest.run([])
      ensure
        STDOUT.reopen(saved_fd)
        saved_fd.close
        $stdout = orig_stdout
      end

      passed ? 0 : 1
    end
  end
end
