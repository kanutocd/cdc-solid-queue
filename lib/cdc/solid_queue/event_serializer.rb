# frozen_string_literal: true

module CDC
  module SolidQueue
    # Converts CDC events into Solid Queue-safe payloads.
    #
    # Payloads are plain hashes so Active Job can serialize them without needing
    # to load the original event object in the queue database.
    class EventSerializer
      # Serialize an event-like object.
      #
      # @param event [Object] event object or Hash
      # @return [Hash] serializable event payload
      # @raise [SerializationError] when the event cannot be represented
      def self.dump(event)
        payload = if event.is_a?(Hash)
                    event
                  elsif event.respond_to?(:to_h)
                    event.to_h
                  else
                    raise SerializationError, 'event must respond to to_h or be a Hash'
                  end

        normalize_hash(payload)
      end

      # Load a serialized event payload.
      #
      # @param payload [Hash]
      # @return [Hash]
      # @raise [SerializationError] when payload is invalid
      def self.load(payload)
        raise SerializationError, 'payload must be a Hash' unless payload.is_a?(Hash)

        normalize_hash(payload)
      end

      # Return the ordering value for a serialized event.
      #
      # @param payload [Hash]
      # @param key [Symbol]
      # @return [Object, nil]
      def self.ordering_value(payload, key)
        normalized = load(payload)
        case key
        when :identity, :primary_key
          normalized['identity'] || normalized['primary_key']
        when :relation
          [normalized['namespace'] || normalized['schema'], normalized['entity'] || normalized['table']]
        when :transaction
          normalized['transaction_id']
        when :global
          normalized['source_position'] || normalized['commit_lsn']
        when :none
          nil
        end
      end

      # Normalize hash keys to strings recursively.
      #
      # @param value [Object]
      # @return [Object]
      def self.normalize_hash(value)
        case value
        when Hash
          # @type var normalized: Hash[String, untyped]
          normalized = {}
          value.each_with_object(normalized) do |(key, child), normalized|
            normalized[key.to_s] = normalize_hash(child)
          end
        when Array
          value.map { |child| normalize_hash(child) }
        when String, Symbol, Numeric, true, false, nil
          value
        else
          value.to_s
        end
      end
      private_class_method :normalize_hash
    end
  end
end
