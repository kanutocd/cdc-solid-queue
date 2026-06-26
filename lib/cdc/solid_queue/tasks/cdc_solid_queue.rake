# frozen_string_literal: true

namespace :cdc_solid_queue do
  desc 'Start PostgreSQL CDC ingestion into Solid Queue'
  task start: :environment do
    CDC::SolidQueue::CLI.start
  end
end
