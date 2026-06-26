# Changelog

## Unreleased

- Batch-sized enqueueing now feeds arrays into downstream `process_many`, so
  the Solid Queue job path matches batch-style downstream runtimes.

## 0.2.0

- Optional downstream processor delegation to `cdc-concurrent` and `cdc-parallel`.
- Rails example now demonstrates `cdc-concurrent` downstream processing.
- Benchmark can measure direct downstream delegation overhead.

## 0.1.2

- Minimal Rails app example.
- Local smoke tests.
- Enqueue overhead benchmark.

## 0.1.1

- Initial implementation skeleton.
- Configuration object.
- Event serializer.
- Enqueuer.
- ProcessorJob mixin.
- Queue selection through Active Job `set(queue:)`.
- Ordering metadata on enqueued CDC payloads.
- `CDC::Core::ChangeEvent` rehydration for processor jobs.
- Checkpoint advancement after successful enqueue.
- PostgreSQL pgoutput normalization stream wiring.
- Rails `cdc_solid_queue:start` task integration.
- Test coverage gate.
- RBS signatures.
