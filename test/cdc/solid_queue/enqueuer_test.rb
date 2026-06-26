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

  def test_enqueue_uses_perform_later
    enqueuer = CDC::SolidQueue::Enqueuer.new(config_for(LaterJob))

    assert_equal :later, enqueuer.enqueue(id: 1)
    assert_equal({ 'id' => 1 }, LaterJob.payloads.last)
  end

  def test_enqueue_falls_back_to_perform_now
    enqueuer = CDC::SolidQueue::Enqueuer.new(config_for(NowJob))

    assert_equal :now, enqueuer.enqueue(id: 2)
    assert_equal({ 'id' => 2 }, NowJob.payloads.last)
  end

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
end
