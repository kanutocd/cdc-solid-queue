# frozen_string_literal: true

module CDC
  module SolidQueue
    # Minimal ingestion runner boundary.
    #
    # The runner accepts any stream object that yields PostgreSQL-derived CDC
    # events. This keeps the class testable while production code can supply a
    # pgoutput-client backed stream.
    class Runner
      # @param stream [#each]
      # @param enqueuer [Enqueuer]
      def initialize(stream:, enqueuer:)
        raise ArgumentError, 'stream must respond to #each' unless stream.respond_to?(:each)

        @stream = stream
        @enqueuer = enqueuer
      end

      # Start reading events and enqueueing jobs.
      #
      # @return [Integer] number of enqueued events
      def start
        # @type var batch: Array[untyped]
        batch = []
        count = 0

        @stream.each do |event|
          batch << event
          next unless batch.length >= @enqueuer.configuration.batch_size

          count += flush_batch(batch)
          batch = []
        end

        count + flush_batch(batch)
      end

      private

      def flush_batch(batch)
        return 0 if batch.empty?

        result = @enqueuer.enqueue(batch.length == 1 ? batch.first : batch.dup)
        checkpoint(batch, result)
        batch.length
      end

      def checkpoint(event, result)
        store = @enqueuer.configuration.checkpoint
        store&.advance(event, result)
      end
    end
  end
end
