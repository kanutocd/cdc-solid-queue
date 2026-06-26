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
      # @param event [Object, Hash, Array<Object>]
      # @return [Object] Active Job return value
      def enqueue(event)
        payload = payload_for(event)
        payload = EventSerializer.with_enqueue_metadata(payload, enqueue_metadata(payload))
        job = configuration.processor_job
        return async_job(job).perform_later(payload) if job.respond_to?(:perform_later)

        job.perform_now(payload)
      end

      private

      def async_job(job)
        return job.set(queue: configuration.queue) if job.respond_to?(:set)

        job
      end

      def enqueue_metadata(payload)
        {
          'queue' => configuration.queue,
          'preserve_order' => configuration.preserve_order,
          'ordering_key' => configuration.ordering_key,
          'ordering_value' => ordering_value(payload),
          'batch_size' => configuration.batch_size
        }
      end

      def ordering_value(payload)
        return nil unless configuration.preserve_order

        if payload.is_a?(Array)
          payload.map { |event| EventSerializer.ordering_value(event, configuration.ordering_key) }
        else
          EventSerializer.ordering_value(payload, configuration.ordering_key)
        end
      end

      def payload_for(event)
        return EventSerializer.dump_batch(event) if event.is_a?(Array)

        EventSerializer.dump(event)
      end
    end
  end
end
