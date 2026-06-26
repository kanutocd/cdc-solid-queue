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
    # event is a serialized CDC event Hash
  end
end
```

```ruby
CDC::SolidQueue.configure do |config|
  config.processor_job = UserChangedJob
  config.queue = "cdc"
  config.preserve_order = true
  config.ordering_key = :identity
  config.postgresql = {
    slot: "cdc_solid_queue",
    publication: "cdc_publication"
  }
end
```

## MVP Checkpoint Rule

A checkpoint may advance after the Solid Queue job is durably inserted. Job execution success is handled by Solid Queue retry semantics.

## Quality Gates

The first implementation is designed around:

- 100% line coverage
- 100% branch coverage
- RBS validation
- RuboCop configuration
- YARD documentation
