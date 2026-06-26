# frozen_string_literal: true

module CDC
  module SolidQueue
    # Enqueues normalized CDC events as Solid Queue-backed Active Job jobs.
    class Enqueuer
      # @return [Configuration]
      attr_reader :configuration

      # @param configuration [Configuration]
      def initialize(configuration)
        @configuration = configuration
        @configuration.validate!
      end

      # Enqueue one CDC event.
      #
      # @param event [Object, Hash]
      # @return [Object] Active Job return value
      def enqueue(event)
        payload = EventSerializer.dump(event)
        job = configuration.processor_job
        return job.perform_later(payload) if job.respond_to?(:perform_later)

        job.perform_now(payload)
      end
    end
  end
end
