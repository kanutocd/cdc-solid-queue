# frozen_string_literal: true

require 'rails/railtie'

module CDC
  module SolidQueue
    # Rails integration for cdc-solid-queue tasks.
    class Railtie < Rails::Railtie
      rake_tasks do
        load File.expand_path('tasks/cdc_solid_queue.rake', File.dirname(__FILE__))
      end
    end
  end
end
