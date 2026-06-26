# frozen_string_literal: true

module CDC
  module SolidQueue
    # Command helpers used by Rails tasks and executable entrypoints.
    module CLI
      class << self
        # Start PostgreSQL CDC ingestion using the global configuration.
        #
        # @return [Integer] number of enqueued events when the stream exits
        def start
          configuration = CDC::SolidQueue.configuration
          enqueuer = CDC::SolidQueue::Enqueuer.new(configuration)
          stream = CDC::SolidQueue::PostgresqlStream.new(configuration)

          CDC::SolidQueue::Runner.new(stream:, enqueuer:).start
        end
      end
    end
  end
end
