# frozen_string_literal: true

require_relative "../test_helper"

# The Minitest runner (wrapping MinitestIntegration) must keep its 0/1 contract.
# Run in a fork because the runner manipulates global Minitest state (autorun,
# runnables) that only makes sense in a throwaway child.
class TestRunnersMinitestTest < Minitest::Test
  FIX     = File.expand_path("../fixtures", __dir__)
  PASSING = File.join(FIX, "calculator_strong_test.rb")
  FAILING = File.join(FIX, "failing_minitest_test.rb")
  # Wraps each assertion in capture_subprocess_io, which reopens $stdout.
  SUBPROCESS_IO = File.join(FIX, "calculator_subprocess_io_test.rb")
  NOISY = File.join(FIX, "noisy_minitest_test.rb")
  # Leaves $stdout as a StringIO, at load time and inside a test.
  STDOUT_SWAP = File.join(FIX, "calculator_stdout_swap_test.rb")

  def fork_status
    pid = fork { exit!(yield) }
    _, status = Process.waitpid2(pid)
    status.exitstatus
  end

  # Returns [exitstatus, captured_real_stdout]. The child points fd 1 at a pipe
  # so the test sees what would reach the parent's terminal.
  def fork_status_and_stdout
    rd, wr = IO.pipe
    pid = fork do
      rd.close
      $stdout.reopen(wr)
      code = yield
      $stdout.flush
      exit!(code)
    end
    wr.close
    out = rd.read
    rd.close
    _, status = Process.waitpid2(pid)
    [status.exitstatus, out]
  end

  def test_passing_suite_returns_zero
    assert_equal 0, fork_status { Mutineer::TestRunners::Minitest.run([PASSING]) }
  end

  def test_suite_that_reopens_stdout_returns_zero
    assert_equal 0, fork_status { Mutineer::TestRunners::Minitest.run([SUBPROCESS_IO]) }
  end

  def test_test_output_is_silenced
    code, out = fork_status_and_stdout { Mutineer::TestRunners::Minitest.run([NOISY]) }
    assert_equal 0, code
    assert_empty out, "test output should be silenced"
  end

  def test_suite_that_swaps_stdout_for_a_stringio_returns_zero_and_restores
    code, out = fork_status_and_stdout do
      status = Mutineer::TestRunners::Minitest.run([STDOUT_SWAP])
      $stdout.puts "AFTER-RUN"
      status
    end
    assert_equal 0, code
    assert_equal "AFTER-RUN\n", out
  end

  def test_stdout_is_restored_after_the_run
    _, out = fork_status_and_stdout do
      Mutineer::TestRunners::Minitest.run([NOISY])
      $stdout.puts "AFTER-RUN"
      0
    end
    assert_equal "AFTER-RUN\n", out
  end

  def test_failing_suite_returns_one
    assert_equal 1, fork_status { Mutineer::TestRunners::Minitest.run([FAILING]) }
  end
end
