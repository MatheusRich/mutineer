# frozen_string_literal: true

require "minitest/autorun"
require_relative "tally"

# Deliberately sums only an empty list. So the `+=` -> `-=` mutation
# survives undetected.
class TallyTest < Minitest::Test
  def test_sum_of_nothing_is_zero
    assert_equal 0, Tally.new.sum([])
  end
end
