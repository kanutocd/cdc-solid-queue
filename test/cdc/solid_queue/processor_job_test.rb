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
end
