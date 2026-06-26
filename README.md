# cdc-solid-queue

Rails-native durable CDC job backend for Solid Queue.

```text
PostgreSQL WAL
  -> pgoutput-client
  -> pgoutput-parser / pgoutput-decoder
  -> pgoutput-source-adapter
  -> CDC::Core::ChangeEvent
  -> cdc-solid-queue
  -> Solid Queue
  -> ApplicationJob
```

## Requirements

- Ruby 3.4+
- Rails 7.1+
- Solid Queue 1.0+
- PostgreSQL logical replication

Only PostgreSQL is supported in the initial implementation.

## Usage

```ruby
class UserChangedJob < ApplicationJob
  include CDC::SolidQueue::ProcessorJob

  def process(event)
    # event is a CDC::Core::ChangeEvent
  end
end
```

```ruby
CDC::SolidQueue.configure do |config|
  config.processor_job = UserChangedJob
  config.queue = "cdc"
  config.preserve_order = true
  config.ordering_key = :identity
  config.checkpoint = CDC::SolidQueue::Checkpoint.new
  config.postgresql = {
    database_url: ENV.fetch("DATABASE_URL"),
    slot: "cdc_solid_queue",
    publication: "cdc_publication"
  }
end
```

`config.queue` is applied through Active Job's `set(queue:)` API when the job
class supports it. When `preserve_order` is enabled, the enqueued payload also
includes cdc-solid-queue metadata with the configured ordering key and computed
ordering value. Set `config.batch_size` above `1` to enqueue multiple CDC
events in one Solid Queue job and hand the batch to downstream `process_many`.

## Downstream Processing

Processor jobs can delegate work to CDC downstream runtime primitives. The
default downstream runtime is `:concurrent`, backed by `cdc-concurrent`, which
fits Solid Queue jobs that spend most of their time on I/O. CPU-heavy work can
opt into `:parallel`, backed by `cdc-parallel`, in Ruby 4 applications.

```ruby
class WebhookProcessor < CDC::Core::Processor
  concurrent_safe!

  def process(event)
    # perform I/O-bound work
    CDC::Core::ProcessorResult.success(event)
  end
end

CDC::SolidQueue.configure do |config|
  config.processor_job = UserChangedJob
  config.downstream_processor = WebhookProcessor.new
  config.downstream_runtime = :concurrent
  config.downstream_options = { concurrency: 100, timeout: 5.0 }
end
```

Use `:parallel` only when the processor is Ractor-safe and the application runs
on Ruby 4:

```ruby
config.downstream_runtime = :parallel
config.downstream_options = { size: 4, timeout: 5 }
```

Both runtime gems are optional. Add `cdc-concurrent` or `cdc-parallel` to the
application Gemfile when selecting that runtime. Without a configured
`downstream_processor`, `CDC::SolidQueue::ProcessorJob` falls back to the job's
own `#process(event)` method.

## Rails Task

Rails applications can load the Railtie integration:

```ruby
require "cdc/solid_queue/railtie"
```

Then start ingestion with:

```bash
bin/rails cdc_solid_queue:start
```

The task wires `Pgoutput::Client::Runner`, `Pgoutput::RelationTracker`,
`Pgoutput::Decoder`, and `Pgoutput::SourceAdapter::Cdc` into the
`CDC::SolidQueue::Runner`.

See `examples/rails_app` for a minimal Rails-side setup with a Solid Queue job,
initializer, Railtie require, and a local PostgreSQL container configured for
logical replication.

## Smoke Tests

Run local smoke tests without PostgreSQL or Rails:

```bash
bundle exec rake smoke:local
```

The smoke tests verify enqueue metadata, event rehydration, and
checkpoint-after-enqueue behavior.

## Benchmark

Run the enqueue overhead benchmark:

```bash
bundle exec rake benchmark:enqueue
```

Set `CDC_SOLID_QUEUE_BENCH_EVENTS` to control the event count.
Set `CDC_SOLID_QUEUE_BENCH_MODE=downstream_direct` to measure direct downstream
processor delegation overhead without Solid Queue enqueue translation.
Set `CDC_SOLID_QUEUE_BENCH_MODE=downstream_batch` to measure batched downstream
delegation overhead. Set `CDC_SOLID_QUEUE_BENCH_BATCH_SIZE` to control the batch
width.

Example local result on Ruby 3.4.9:

```text
events=1000000 elapsed=15.7210s rate=63609.14 events/s
```

This is an upper-bound microbenchmark for the Ruby-side enqueue translation
layer. It measures event serialization, queue and ordering metadata calculation,
and dispatch to a fake benchmark job. It does not measure real Solid Queue
database inserts, Rails job execution, PostgreSQL replication, pgoutput
decoding, network I/O, or checkpoint persistence.

In that run, `cdc-solid-queue` translated and dispatched about 63.6k synthetic
events per second, so real throughput will usually be dominated by Solid Queue
persistence, database latency, job execution cost, and CDC source throughput.

Example `downstream_direct` results on the same machine:

```text
mode=downstream_direct events=100000000 elapsed=16.2669s rate=6147457.32 events/s
mode=downstream_direct events=1000000000 elapsed=157.8708s rate=6334292.58 events/s
```

These runs measure the lowest-overhead downstream delegation path:

```text
CDC::SolidQueue::DownstreamProcessor
  -> :direct runtime branch
  -> BenchmarkProcessor#process(event)
```

They do not measure Solid Queue enqueueing, Active Job serialization,
PostgreSQL CDC, pgoutput parsing or decoding, `cdc-concurrent`,
`cdc-parallel`, real application processor work, network I/O, or database I/O.
The result means the direct downstream adapter can dispatch about 6.1M to 6.3M
prebuilt synthetic events per second on that machine, making the adapter layer
negligible compared with real persistence, CDC source, and processor costs.

Batch mode example:

```text
mode=downstream_batch events=100000000 elapsed=... rate=... events/s
```

Batch mode measures one more layer: batch deserialization plus `process_many`
dispatch through the downstream adapter. When a downstream runtime such as
`cdc-concurrent` or `cdc-parallel` is configured, that batch is handed to the
runtime pool in one call instead of event-by-event.

## MVP Checkpoint Rule

A checkpoint advances after the Solid Queue job is durably inserted. Job execution success is handled by Solid Queue retry semantics.

## Quality Gates

The first implementation is designed around:

- 100% line coverage
- 100% branch coverage
- RBS validation
- RuboCop configuration
- YARD documentation
