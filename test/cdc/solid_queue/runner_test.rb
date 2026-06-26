# frozen_string_literal: true

require_relative '../../test_helper'

class RunnerTest < Minitest::Test
  FakeEnqueuer = Struct.new(:events) do
    def configuration
      config = CDC::SolidQueue::Configuration.new
      config.processor_job = EnqueuerTest::LaterJob
      config.postgresql = { slot: 'cdc' }
      config.batch_size = 1
      config
    end

    def enqueue(event)
      events << event
    end
  end

  FailingEnqueuer = Struct.new(:configuration) do
    def enqueue(_event)
      raise 'enqueue failed'
    end
  end

  CheckpointStore = Struct.new(:advanced) do
    def advance(event, result)
      advanced << [event, result]
    end
  end

  def test_rejects_stream_without_each
    assert_raises(ArgumentError) { CDC::SolidQueue::Runner.new(stream: Object.new, enqueuer: FakeEnqueuer.new([])) }
  end

  def test_start_enqueues_each_event_and_returns_count
    events = []
    runner = CDC::SolidQueue::Runner.new(stream: [{ id: 1 }, { id: 2 }], enqueuer: FakeEnqueuer.new(events))

    assert_equal 2, runner.start
    assert_equal [{ id: 1 }, { id: 2 }], events
  end

  def test_start_batches_events_before_enqueueing
    events = []
    enqueuer = FakeEnqueuer.new(events)
    enqueuer.define_singleton_method(:configuration) do
      config = CDC::SolidQueue::Configuration.new
      config.processor_job = EnqueuerTest::LaterJob
      config.postgresql = { slot: 'cdc' }
      config.batch_size = 2
      config
    end

    runner = CDC::SolidQueue::Runner.new(stream: [{ id: 1 }, { id: 2 }, { id: 3 }], enqueuer: enqueuer)

    assert_equal 3, runner.start
    assert_equal [[{ id: 1 }, { id: 2 }], { id: 3 }], events
  end

  def test_start_checkpoints_after_successful_enqueue
    checkpoint = CheckpointStore.new([])
    config = config_with_checkpoint(checkpoint)
    enqueuer = Object.new
    enqueuer.define_singleton_method(:configuration) { config }
    enqueuer.define_singleton_method(:enqueue) { |event| [:enqueued, event] }

    runner = CDC::SolidQueue::Runner.new(stream: [{ id: 1 }], enqueuer: enqueuer)

    assert_equal 1, runner.start
    assert_equal [[[{ id: 1 }], [:enqueued, { id: 1 }]]], checkpoint.advanced
  end

  def test_start_does_not_checkpoint_failed_enqueue
    checkpoint = CheckpointStore.new([])
    runner = CDC::SolidQueue::Runner.new(
      stream: [{ id: 1 }],
      enqueuer: FailingEnqueuer.new(config_with_checkpoint(checkpoint))
    )

    assert_raises(RuntimeError) { runner.start }
    assert_empty checkpoint.advanced
  end

  def test_start_allows_nil_checkpoint
    config = config_with_checkpoint(nil)
    enqueuer = Object.new
    enqueuer.define_singleton_method(:configuration) { config }
    enqueuer.define_singleton_method(:enqueue) { |event| [:enqueued, event] }

    runner = CDC::SolidQueue::Runner.new(stream: [{ id: 1 }], enqueuer: enqueuer)

    assert_equal 1, runner.start
  end

  private

  def config_with_checkpoint(checkpoint)
    CDC::SolidQueue::Configuration.new.tap do |config|
      config.processor_job = EnqueuerTest::LaterJob
      config.postgresql = { slot: 'cdc' }
      config.checkpoint = checkpoint
    end
  end
end
