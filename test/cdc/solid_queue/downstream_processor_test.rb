# frozen_string_literal: true

require_relative '../../test_helper'

# rubocop:disable Metrics/ClassLength
class DownstreamProcessorTest < Minitest::Test
  Processor = Struct.new(:events) do
    def process(event)
      events << event
      :processed
    end
  end

  ManyProcessor = Struct.new(:events) do
    def process(event)
      events << event
      :processed
    end

    def process_many(batch)
      events << batch
      :processed_many
    end
  end

  Runtime = Struct.new(:processor, :options, :items, :shutdowns) do
    def process(item)
      items << item
      processor.process(item)
    end

    def process_many(batch)
      items << batch
      if processor.respond_to?(:process_many)
        processor.process_many(batch)
      else
        batch.map { |item| processor.process(item) }
      end
    end

    def shutdown
      shutdowns << true
    end
  end

  RuntimeFactory = Struct.new(:created, :items, :shutdowns) do
    def new(processor:, **options)
      runtime = Runtime.new(processor, options, items, shutdowns)
      created << runtime
      runtime
    end
  end

  def test_direct_runtime_processes_with_processor
    events = []
    config = config_for(Processor.new(events), runtime: :direct)

    assert_equal :processed, CDC::SolidQueue::DownstreamProcessor.new(config).process(:event)
    assert_equal [:event], events
  end

  def test_direct_runtime_processes_many_with_processor
    events = []
    config = config_for(Processor.new(events), runtime: :direct)

    assert_equal %i[processed processed], CDC::SolidQueue::DownstreamProcessor.new(config).process_many(%i[a b])
    assert_equal %i[a b], events
  end

  def test_concurrent_runtime_processes_and_shutdowns
    factory = RuntimeFactory.new([], [], [])
    with_runtime(:Concurrent, factory) do
      config = config_for(Processor.new([]), options: { concurrency: 10, timeout: 1.0 })

      assert_equal :processed, CDC::SolidQueue::DownstreamProcessor.new(config).process(:event)
      assert_equal [[:event]], factory.items
      assert_equal [true], factory.shutdowns
      assert_equal({ concurrency: 10, timeout: 1.0 }, factory.created.fetch(0).options)
    end
  end

  def test_concurrent_runtime_processes_many_and_shutdowns
    factory = RuntimeFactory.new([], [], [])
    with_runtime(:Concurrent, factory) do
      config = config_for(Processor.new([]), options: { concurrency: 10, timeout: 1.0 })

      assert_equal %i[processed processed],
                   CDC::SolidQueue::DownstreamProcessor.new(config).process_many(%i[a b])
      assert_equal [%i[a b]], factory.items
      assert_equal [true], factory.shutdowns
      assert_equal({ concurrency: 10, timeout: 1.0 }, factory.created.fetch(0).options)
    end
  end

  def test_parallel_runtime_processes_and_shutdowns
    factory = RuntimeFactory.new([], [], [])
    with_runtime(:Parallel, factory) do
      config = config_for(Processor.new([]), runtime: :parallel, options: { size: 2 })

      assert_equal :processed, CDC::SolidQueue::DownstreamProcessor.new(config).process(:event)
      assert_equal [[:event]], factory.items
      assert_equal [true], factory.shutdowns
      assert_equal({ size: 2 }, factory.created.fetch(0).options)
    end
  end

  def test_parallel_runtime_processes_many_and_shutdowns
    factory = RuntimeFactory.new([], [], [])
    with_runtime(:Parallel, factory) do
      config = config_for(Processor.new([]), runtime: :parallel, options: { size: 2 })

      assert_equal %i[processed processed],
                   CDC::SolidQueue::DownstreamProcessor.new(config).process_many(%i[a b])
      assert_equal [%i[a b]], factory.items
      assert_equal [true], factory.shutdowns
      assert_equal({ size: 2 }, factory.created.fetch(0).options)
    end
  end

  def test_missing_concurrent_runtime_raises_configuration_error
    config = config_for(Processor.new([]))

    error = assert_raises(CDC::SolidQueue::ConfigurationError) do
      CDC::SolidQueue::DownstreamProcessor.new(config).process(:event)
    end
    assert_match(/cdc-concurrent/, error.message)
  end

  def test_missing_parallel_runtime_raises_configuration_error
    config = config_for(Processor.new([]), runtime: :parallel)

    error = assert_raises(CDC::SolidQueue::ConfigurationError) do
      CDC::SolidQueue::DownstreamProcessor.new(config).process(:event)
    end
    assert_match(/cdc-parallel/, error.message)
  end

  def test_unknown_runtime_raises_configuration_error
    config = config_for(Processor.new([]), runtime: :direct)
    config.downstream_runtime = :unknown

    error = assert_raises(CDC::SolidQueue::ConfigurationError) do
      CDC::SolidQueue::DownstreamProcessor.new(config).process(:event)
    end
    assert_match(/unsupported downstream_runtime/, error.message)
  end

  def test_process_many_unknown_runtime_raises_configuration_error
    config = config_for(Processor.new([]), runtime: :direct)
    config.downstream_runtime = :unknown

    error = assert_raises(CDC::SolidQueue::ConfigurationError) do
      CDC::SolidQueue::DownstreamProcessor.new(config).process_many(%i[a b])
    end
    assert_match(/unsupported downstream_runtime/, error.message)
  end

  def test_missing_downstream_processor_raises_configuration_error
    config = config_for(nil, runtime: :direct)

    error = assert_raises(CDC::SolidQueue::ConfigurationError) do
      CDC::SolidQueue::DownstreamProcessor.new(config).process(:event)
    end
    assert_match(/downstream_processor/, error.message)
  end

  def test_concurrent_runtime_uses_processor_process_many_result
    factory = RuntimeFactory.new([], [], [])
    with_runtime(:Concurrent, factory) do
      config = config_for(ManyProcessor.new([]), options: { concurrency: 10 })

      assert_equal :processed_many, CDC::SolidQueue::DownstreamProcessor.new(config).process(:event)
      assert_equal [[:event]], factory.items
    end
  end

  private

  def config_for(processor, runtime: :concurrent, options: {})
    CDC::SolidQueue::Configuration.new.tap do |config|
      config.downstream_processor = processor
      config.downstream_runtime = runtime
      config.downstream_options = options
    end
  end

  def with_runtime(name, factory)
    remove_runtime(name)
    CDC.const_set(name, Module.new)
    CDC.const_get(name).const_set(:Runtime, factory)
    yield
  ensure
    remove_runtime(name)
  end

  def remove_runtime(name)
    CDC.send(:remove_const, name) if CDC.const_defined?(name, false)
  end
end
# rubocop:enable Metrics/ClassLength
