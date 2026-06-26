# frozen_string_literal: true

require 'cdc/solid_queue'

# Fake Active Job class used by the enqueue smoke test.
class SmokeJob
  @payloads = []
  @queues = []

  class << self
    attr_reader :payloads, :queues

    def set(queue:)
      @queues << queue
      self
    end

    def perform_later(payload)
      @payloads << payload
      :enqueued
    end
  end
end

config = CDC::SolidQueue::Configuration.new
config.processor_job = SmokeJob
config.queue = 'cdc_smoke'
config.postgresql = { slot: 'cdc_solid_queue', publication: 'cdc_publication' }

enqueuer = CDC::SolidQueue::Enqueuer.new(config)
result = enqueuer.enqueue(
  operation: :insert,
  schema: 'public',
  table: 'users',
  primary_key: { id: 1 },
  commit_lsn: '0/1'
)

raise 'unexpected enqueue result' unless result == :enqueued
raise 'queue was not applied' unless SmokeJob.queues == ['cdc_smoke']

payload = SmokeJob.payloads.fetch(0)
event = CDC::SolidQueue::EventSerializer.load_event(payload)
metadata = CDC::SolidQueue::EventSerializer.enqueue_metadata(payload)

raise 'event was not rehydrated' unless event.is_a?(CDC::Core::ChangeEvent)
raise 'unexpected table' unless event.qualified_table_name == 'public.users'
raise 'ordering metadata missing' unless metadata['ordering_key'] == :identity

puts 'enqueue smoke passed'
