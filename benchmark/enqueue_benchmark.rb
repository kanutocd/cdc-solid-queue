# frozen_string_literal: true

require 'benchmark'
require 'cdc/solid_queue'

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

events = Integer(ENV.fetch('CDC_SOLID_QUEUE_BENCH_EVENTS', '10000'))

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
  events.times { enqueuer.enqueue(event) }
end

rate = events / elapsed

puts format('events=%<events>d elapsed=%<elapsed>.4fs rate=%<rate>.2f events/s', events:, elapsed:, rate:)
