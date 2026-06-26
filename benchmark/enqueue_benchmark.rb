# frozen_string_literal: true

require 'benchmark'
require 'cdc/solid_queue'
require 'cdc/core'

# Fake Active Job class used by the enqueue benchmark.
class BenchmarkJob
  @count = 0

  class << self
    attr_reader :count

    def perform_later(_payload)
      @count += 1
    end
  end
end

BenchmarkProcessor = Class.new(CDC::Core::Processor) do
  def process(event)
    event
  end
end

events = Integer(ENV.fetch('CDC_SOLID_QUEUE_BENCH_EVENTS', '10000'))
mode = ENV.fetch('CDC_SOLID_QUEUE_BENCH_MODE', 'enqueue')

config = CDC::SolidQueue::Configuration.new
config.processor_job = BenchmarkJob
config.queue = 'cdc_benchmark'
config.postgresql = { slot: 'cdc_solid_queue', publication: 'cdc_publication' }

enqueuer = CDC::SolidQueue::Enqueuer.new(config)
event = {
  operation: :insert,
  schema: 'public',
  table: 'users',
  primary_key: { id: 1 },
  commit_lsn: '0/1'
}

elapsed = Benchmark.realtime do
  case mode
  when 'enqueue'
    events.times { enqueuer.enqueue(event) }
  when 'downstream_direct'
    config.downstream_processor = BenchmarkProcessor.new
    config.downstream_runtime = :direct
    processor = CDC::SolidQueue::DownstreamProcessor.new(config)
    change_event = CDC::SolidQueue::EventSerializer.load_event(event)
    events.times { processor.process(change_event) }
  else
    raise ArgumentError, "unknown benchmark mode: #{mode}"
  end
end

rate = events / elapsed

puts format(
  'mode=%<mode>s events=%<events>d elapsed=%<elapsed>.4fs rate=%<rate>.2f events/s',
  mode:,
  events:,
  elapsed:,
  rate:
)
