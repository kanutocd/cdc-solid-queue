# frozen_string_literal: true

require 'cdc/solid_queue'

# Fake Active Job class used by the runner checkpoint smoke test.
class CheckpointSmokeJob
  def self.perform_later(payload)
    payload
  end
end

config = CDC::SolidQueue::Configuration.new
config.processor_job = CheckpointSmokeJob
config.postgresql = { slot: 'cdc_solid_queue', publication: 'cdc_publication' }

runner = CDC::SolidQueue::Runner.new(
  stream: [{ operation: :insert, schema: 'public', table: 'users', commit_lsn: '0/2' }],
  enqueuer: CDC::SolidQueue::Enqueuer.new(config)
)

count = runner.start

raise 'unexpected count' unless count == 1
raise 'checkpoint did not advance' unless config.checkpoint.position == '0/2'

puts 'runner checkpoint smoke passed'
