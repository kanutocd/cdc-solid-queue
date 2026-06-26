# Changelog

## Unreleased

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
