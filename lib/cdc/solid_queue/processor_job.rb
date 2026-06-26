# frozen_string_literal: true

module CDC
  module SolidQueue
    # Mixin for Rails ApplicationJob classes that consume CDC event payloads.
    #
    # Including classes implement #process(event). Active Job calls #perform,
    # this mixin deserializes the payload, then delegates to #process.
    module ProcessorJob
      # Add a default queue name when Active Job provides queue_as.
      #
      # @param base [Class]
      # @return [void]
      def self.included(base)
        base.queue_as(:cdc) if base.respond_to?(:queue_as)
      end

      # Active Job entrypoint.
      #
      # @param payload [Hash]
      # @return [Object] process return value
      def perform(payload)
        process(EventSerializer.load(payload))
      end

      # Process a normalized CDC event payload.
      #
      # @param event [Hash]
      # @raise [NotImplementedError] when the including job does not override it
      def process(event)
        raise NotImplementedError, "#{self.class} must implement #process"
      end
    end
  end
end
