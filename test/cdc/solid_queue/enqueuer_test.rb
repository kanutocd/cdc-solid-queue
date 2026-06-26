# frozen_string_literal: true

require_relative '../../test_helper'

class EnqueuerTest < Minitest::Test
  LaterJob = Class.new do
    @payloads = []
    class << self
      attr_reader :payloads

      def perform_later(payload)
        @payloads << payload
        :later
      end
    end
  end

  NowJob = Class.new do
    @payloads = []
    class << self
      attr_reader :payloads

      def perform_now(payload)
        @payloads << payload
        :now
      end
    end
  end

  SettableJob = Class.new do
    @payloads = []
    @queues = []
    class << self
      attr_reader :payloads, :queues

      def set(queue:)
        @queues << queue
        self
      end

      def perform_later(payload)
        @payloads << payload
        :later
      end

      def reset!
        @payloads = []
        @queues = []
      end
    end
  end

  def setup
    SettableJob.reset!
  end

  def test_enqueue_uses_perform_later
    enqueuer = CDC::SolidQueue::Enqueuer.new(config_for(LaterJob))

    assert_equal :later, enqueuer.enqueue(id: 1)
    assert_equal({ 'id' => 1 }, CDC::SolidQueue::EventSerializer.load(LaterJob.payloads.last))
  end

  def test_enqueue_falls_back_to_perform_now
    enqueuer = CDC::SolidQueue::Enqueuer.new(config_for(NowJob))

    assert_equal :now, enqueuer.enqueue(id: 2)
    assert_equal({ 'id' => 2 }, CDC::SolidQueue::EventSerializer.load(NowJob.payloads.last))
  end

  def test_enqueue_sets_active_job_queue_and_metadata
    config = config_for(SettableJob)
    config.queue = 'critical_cdc'
    enqueuer = CDC::SolidQueue::Enqueuer.new(config)

    assert_equal :later, enqueuer.enqueue(identity: 42)
    assert_equal ['critical_cdc'], SettableJob.queues
    metadata = CDC::SolidQueue::EventSerializer.enqueue_metadata(SettableJob.payloads.last)

    assert_equal expected_metadata('critical_cdc', 42), metadata
  end

  def test_enqueue_omits_ordering_value_when_ordering_is_disabled
    config = config_for(SettableJob)
    config.preserve_order = false
    enqueuer = CDC::SolidQueue::Enqueuer.new(config)

    enqueuer.enqueue(identity: 42)

    assert_nil CDC::SolidQueue::EventSerializer.enqueue_metadata(SettableJob.payloads.last)['ordering_value']
  end

  # rubocop:disable Metrics/AbcSize
  def test_enqueue_batches_payloads_with_batch_metadata
    config = config_for(SettableJob)
    config.batch_size = 2
    enqueuer = CDC::SolidQueue::Enqueuer.new(config)

    assert_equal :later, enqueuer.enqueue([{ identity: 1 }, { identity: 2 }])
    metadata = CDC::SolidQueue::EventSerializer.enqueue_metadata(SettableJob.payloads.last)

    assert_equal 2, metadata.length
    assert_equal 2, metadata.fetch(0).fetch('batch_size')
    assert_equal 0, metadata.fetch(0).fetch('batch_index')
    assert_equal 1, metadata.fetch(1).fetch('batch_index')
  end
  # rubocop:enable Metrics/AbcSize

  def test_initialize_validates_configuration
    config = config_for(LaterJob)
    config.processor_job = nil
    assert_raises(CDC::SolidQueue::ConfigurationError) { CDC::SolidQueue::Enqueuer.new(config) }
  end

  private

  def config_for(job)
    CDC::SolidQueue::Configuration.new.tap do |config|
      config.processor_job = job
      config.postgresql = { slot: 'cdc' }
    end
  end

  def expected_metadata(queue, ordering_value)
    {
      'queue' => queue,
      'preserve_order' => true,
      'ordering_key' => :identity,
      'ordering_value' => ordering_value,
      'batch_size' => 1
    }
  end
end
