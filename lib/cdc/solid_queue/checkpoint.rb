# frozen_string_literal: true

module CDC
  module SolidQueue
    # Minimal in-memory checkpoint store.
    #
    # Applications that need durable replay safety should provide a persistent
    # object that responds to #advance(event, result).
    class Checkpoint
      # @return [Object, nil]
      attr_reader :position

      # Build an empty checkpoint.
      def initialize
        @position = nil
      end

      # Advance to the best known source position for an enqueued event.
      #
      # @param event [Object]
      # @param result [Object]
      # @return [Object, nil]
      def advance(event, result = nil)
        @position = position_for(event) || result_position(result) || @position
      end

      private

      def position_for(event)
        return event.map { |item| position_for(item) }.compact.last if event.is_a?(Array)

        payload = EventSerializer.dump(event)
        payload['source_position'] || payload['commit_lsn'] || payload.dig('metadata', 'wal_end_lsn')
      rescue SerializationError
        nil
      end

      def result_position(result)
        return result.checkpoint_position if result.respond_to?(:checkpoint_position)

        nil
      end
    end
  end
end
