# frozen_string_literal: true

require_relative '../../test_helper'

# rubocop:disable Metrics/ClassLength
class ConfigurationTest < Minitest::Test
  JobWithLater = Class.new do
    def self.perform_later(_payload) = :later
  end

  JobWithNow = Class.new do
    def self.perform_now(_payload) = :now
  end

  def test_defaults
    config = CDC::SolidQueue::Configuration.new

    assert_equal 'cdc', config.queue
    assert config.preserve_order
    assert_equal :identity, config.ordering_key
    assert_equal :postgresql, config.source
    assert_equal 1, config.batch_size
  end

  def test_defaults_auto_create_slot_to_false
    config = CDC::SolidQueue::Configuration.new

    refute config.auto_create_slot
  end

  def test_valid_with_perform_later
    config = valid_config(JobWithLater)

    assert_silent do
      assert config.validate!
    end
  end

  def test_valid_with_perform_now
    config = valid_config(JobWithNow)

    assert_silent do
      config.validate!
    end
  end

  def test_rejects_missing_processor_job
    error = assert_raises(CDC::SolidQueue::ConfigurationError) { valid_config(nil).validate! }
    assert_match(/processor_job/, error.message)
  end

  def test_rejects_empty_queue
    config = valid_config(JobWithLater)
    config.queue = ''
    error = assert_raises(CDC::SolidQueue::ConfigurationError) { config.validate! }
    assert_match(/queue/, error.message)
  end

  def test_rejects_non_string_queue
    config = valid_config(JobWithLater)
    config.queue = :cdc
    error = assert_raises(CDC::SolidQueue::ConfigurationError) { config.validate! }
    assert_match(/queue/, error.message)
  end

  def test_rejects_unknown_ordering_key
    config = valid_config(JobWithLater)
    config.ordering_key = :unknown
    error = assert_raises(CDC::SolidQueue::ConfigurationError) { config.validate! }
    assert_match(/ordering_key/, error.message)
  end

  def test_rejects_non_postgresql_source
    config = valid_config(JobWithLater)
    config.postgresql[:source] = :mysql
    error = assert_raises(CDC::SolidQueue::UnsupportedSourceError) { config.validate! }
    assert_match(/PostgreSQL/, error.message)
  end

  def test_rejects_missing_postgresql_settings
    config = valid_config(JobWithLater)
    config.postgresql = {}
    error = assert_raises(CDC::SolidQueue::ConfigurationError) { config.validate! }
    assert_match(/postgresql/, error.message)
  end

  def test_rejects_invalid_checkpoint
    config = valid_config(JobWithLater)
    config.checkpoint = Object.new

    error = assert_raises(CDC::SolidQueue::ConfigurationError) { config.validate! }
    assert_match(/checkpoint/, error.message)
  end

  def test_rejects_invalid_batch_size
    config = valid_config(JobWithLater)
    config.batch_size = 0

    error = assert_raises(CDC::SolidQueue::ConfigurationError) { config.validate! }
    assert_match(/batch_size/, error.message)
  end

  def test_rejects_invalid_auto_create_slot
    config = valid_config(JobWithLater)
    config.auto_create_slot = 'true'

    error = assert_raises(CDC::SolidQueue::ConfigurationError) { config.validate! }
    assert_match(/auto_create_slot/, error.message)
  end

  def test_defaults_downstream_runtime_to_concurrent
    config = CDC::SolidQueue::Configuration.new

    assert_equal :concurrent, config.downstream_runtime
    assert_nil config.downstream_processor
    assert_equal({}, config.downstream_options)
  end

  def test_rejects_unknown_downstream_runtime
    config = valid_config(JobWithLater)
    config.downstream_runtime = :unknown

    error = assert_raises(CDC::SolidQueue::ConfigurationError) { config.validate! }
    assert_match(/downstream_runtime/, error.message)
  end

  def test_rejects_invalid_downstream_processor
    config = valid_config(JobWithLater)
    config.downstream_processor = Object.new

    error = assert_raises(CDC::SolidQueue::ConfigurationError) { config.validate! }
    assert_match(/downstream_processor/, error.message)
  end

  private

  def valid_config(job)
    CDC::SolidQueue::Configuration.new.tap do |config|
      config.processor_job = job
      config.postgresql = { slot: 'cdc', publication: 'cdc_publication' }
    end
  end
end
# rubocop:enable Metrics/ClassLength
