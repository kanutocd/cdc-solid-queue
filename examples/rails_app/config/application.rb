# frozen_string_literal: true

require 'rails/all'
require 'cdc/solid_queue/railtie'

module ExampleCdcApp
  # Minimal Rails application configuration for the cdc-solid-queue example.
  class Application < Rails::Application
    config.load_defaults 7.1
    config.active_job.queue_adapter = :solid_queue
  end
end
