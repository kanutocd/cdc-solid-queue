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
ordering value.

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

## MVP Checkpoint Rule

A checkpoint advances after the Solid Queue job is durably inserted. Job execution success is handled by Solid Queue retry semantics.

## Quality Gates

The first implementation is designed around:

- 100% line coverage
- 100% branch coverage
- RBS validation
- RuboCop configuration
- YARD documentation
