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
        count = 0
        @stream.each do |event|
          @enqueuer.enqueue(event)
          count += 1
        end
        count
      end
    end
  end
end
