# frozen_string_literal: true

require_relative '../../test_helper'

class RunnerTest < Minitest::Test
  FakeEnqueuer = Struct.new(:events) do
    def enqueue(event)
      events << event
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
end
