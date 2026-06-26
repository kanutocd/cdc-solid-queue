# frozen_string_literal: true

namespace :cdc_solid_queue do
  desc 'Start PostgreSQL CDC ingestion into Solid Queue'
  task start: :environment do
    configuration = CDC::SolidQueue.configuration
    enqueuer = CDC::SolidQueue::Enqueuer.new(configuration)
    stream = CDC::SolidQueue::PostgresqlStream.new(configuration)

    CDC::SolidQueue::Runner.new(stream:, enqueuer:).start
  end
end
