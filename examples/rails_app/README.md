# Rails App Example

This directory shows the minimal Rails-side wiring for `cdc-solid-queue` with a
real local PostgreSQL connection.

It is intentionally a small example instead of a generated Rails application so
the gem repository does not need to vendor a full app skeleton.

## Files

- `Gemfile` shows the application dependencies.
- `config/application.rb` shows the Railtie require.
- `config/database.yml` points Rails at the local PostgreSQL container.
- `config/initializers/cdc_solid_queue.rb` configures ingestion.
- `app/jobs/application_job.rb` provides the Rails job base class.
- `app/jobs/user_changed_job.rb` hands events to the configured downstream runtime.
- `app/processors/webhook_processor.rb` is a `cdc-concurrent` processor.
- `compose.yml` starts PostgreSQL with logical replication enabled.
- `db/init/01_cdc_example.sql` creates the example table and publication.

## Run

Start PostgreSQL:

```bash
docker compose -f examples/rails_app/compose.yml up -d
```

Export the example connection settings:

```bash
set -a
. examples/rails_app/.env.example
set +a
```

From a real Rails application using these example files:

```bash
bin/rails cdc_solid_queue:start
```

The task streams pgoutput payloads, normalizes them to `CDC::Core::ChangeEvent`,
enqueues the configured job through Solid Queue, executes `WebhookProcessor`
through `cdc-concurrent`, and advances the checkpoint after enqueue succeeds.
`WebhookProcessor` implements both `process(event)` and `process_many(events)`,
so when `CDC_BATCH_SIZE` is set above `1`, the example batches multiple events
into one Solid Queue job and hands the batch to downstream `process_many`.

Generate a change event from another terminal:

```bash
psql "$DATABASE_URL" -c "insert into users (email, name) values ('grace@example.test', 'Grace Hopper')"
```
