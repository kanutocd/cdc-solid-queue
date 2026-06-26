# frozen_string_literal: true

require_relative '../test_helper'

class SolidQueueTest < Minitest::Test
  def teardown
    CDC::SolidQueue.reset_configuration!
  end

  def test_version
    refute_nil CDC::SolidQueue::VERSION
  end

  def test_configuration_is_memoized
    assert_same CDC::SolidQueue.configuration, CDC::SolidQueue.configuration
  end

  def test_configure_yields_configuration
    result = CDC::SolidQueue.configure { |config| config.queue = 'changes' }

    assert_equal 'changes', result.queue
    assert_equal 'changes', CDC::SolidQueue.configuration.queue
  end

  def test_reset_configuration
    CDC::SolidQueue.configure { |config| config.queue = 'changes' }

    refute_equal 'changes', CDC::SolidQueue.reset_configuration!.queue
  end
end
