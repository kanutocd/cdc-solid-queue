# frozen_string_literal: true

require_relative '../../test_helper'

class ProcessorJobTest < Minitest::Test
  QueueAwareJob = Class.new do
    @queue = nil
    class << self
      attr_reader :queue

      def queue_as(name) = @queue = name
    end

    include CDC::SolidQueue::ProcessorJob

    attr_reader :processed

    def process(event)
      @processed = event
      :processed
    end
  end

  PlainJob = Class.new do
    include CDC::SolidQueue::ProcessorJob
  end

  DownstreamProcessor = Struct.new(:events) do
    def process(event)
      events << event
      :downstream
    end

    def process_many(batch)
      events << batch
      :downstream_many
    end
  end

  def test_included_sets_default_queue_when_available
    assert_equal :cdc, QueueAwareJob.queue
  end

  def test_perform_loads_payload_and_delegates_to_process
    job = QueueAwareJob.new

    assert_equal :processed, job.perform(id: 1)
    assert_equal({ 'id' => 1 }, job.processed)
  end

  def test_perform_rehydrates_change_event_payload
    job = QueueAwareJob.new
    event = CDC::Core::ChangeEvent.new(operation: :insert, schema: 'public', table: 'users')

    assert_equal :processed, job.perform(event.to_h)
    assert_instance_of CDC::Core::ChangeEvent, job.processed
    assert_equal 'public.users', job.processed.qualified_table_name
  end

  def test_perform_processes_batches_through_process_many
    job = batch_job
    payload = batch_payload

    assert_equal :processed_many, job.perform(payload)
    assert_kind_of Array, job.events
    assert_instance_of CDC::Core::ChangeEvent, job.events.fetch(0)
    assert_instance_of CDC::Core::ChangeEvent, job.events.fetch(1)
  end

  def test_process_must_be_implemented
    error = assert_raises(NotImplementedError) { PlainJob.new.perform(id: 1) }
    assert_match(/must implement/, error.message)
  end

  def test_perform_delegates_to_configured_downstream_processor
    events = []
    CDC::SolidQueue.configure do |config|
      config.downstream_processor = DownstreamProcessor.new(events)
      config.downstream_runtime = :direct
    end

    assert_equal :downstream, PlainJob.new.perform(id: 1)
    assert_equal [{ 'id' => 1 }], events
  ensure
    CDC::SolidQueue.reset_configuration!
  end

  def test_perform_delegates_batches_to_configured_downstream_processor
    events = []
    CDC::SolidQueue.configure do |config|
      config.downstream_processor = DownstreamProcessor.new(events)
      config.downstream_runtime = :direct
    end

    assert_equal :downstream_many, PlainJob.new.perform(batch_payload)
    assert_kind_of Array, events.fetch(0)
    assert_instance_of CDC::Core::ChangeEvent, events.fetch(0).fetch(0)
  ensure
    CDC::SolidQueue.reset_configuration!
  end

  private

  def batch_job
    Class.new do
      include CDC::SolidQueue::ProcessorJob

      attr_reader :events

      def process_many(events)
        @events = events
        :processed_many
      end
    end.new
  end

  def batch_payload
    [
      { operation: :insert, schema: 'public', table: 'users' },
      { operation: :update, schema: 'public', table: 'accounts' }
    ]
  end
end
