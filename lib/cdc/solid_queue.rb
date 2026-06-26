# frozen_string_literal: true

require_relative 'solid_queue/version'
require_relative 'solid_queue/error'
require_relative 'solid_queue/configuration'
require_relative 'solid_queue/event_serializer'
require_relative 'solid_queue/enqueuer'
require_relative 'solid_queue/processor_job'
require_relative 'solid_queue/runner'

# Namespace for Change Data Capture integrations.
module CDC
  # Rails-native durable CDC job backend built on Solid Queue.
  module SolidQueue
    class << self
      # Return the global configuration.
      #
      # @return [Configuration]
      def configuration
        @configuration ||= Configuration.new
      end

      # Configure cdc-solid-queue.
      #
      # @yieldparam config [Configuration]
      # @return [Configuration]
      def configure
        yield configuration
        configuration
      end

      # Reset configuration. Intended for tests and console experiments.
      #
      # @return [Configuration]
      def reset_configuration!
        @configuration = Configuration.new
      end
    end
  end
end
