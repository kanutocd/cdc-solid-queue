# frozen_string_literal: true

module CDC
  module SolidQueue
    # Converts CDC events into Solid Queue-safe payloads.
    #
    # Payloads are plain hashes so Active Job can serialize them without needing
    # to load the original event object in the queue database.
    # rubocop:disable Metrics/ClassLength
    class EventSerializer
      # Reserved payload key for cdc-solid-queue enqueue metadata.
      INTERNAL_METADATA_KEY = '_cdc_solid_queue'
      # Lookup table for ordering value extraction by ordering key.
      ORDERING_VALUE_FETCHERS = {
        identity: ->(payload) { payload['identity'] || payload['primary_key'] },
        primary_key: ->(payload) { payload['identity'] || payload['primary_key'] },
        relation: ->(payload) { [payload['namespace'] || payload['schema'], payload['entity'] || payload['table']] },
        transaction: ->(payload) { payload['transaction_id'] },
        global: ->(payload) { payload['source_position'] || payload['commit_lsn'] }
      }.freeze

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

      # Serialize a batch of event-like objects.
      #
      # @param events [Array<Object>]
      # @return [Array<Hash>]
      def self.dump_batch(events)
        raise SerializationError, 'events must be an Array' unless events.is_a?(Array)

        events.map { |event| dump(event) }
      end

      # Load a serialized event payload.
      #
      # @param payload [Hash]
      # @return [Hash]
      # @raise [SerializationError] when payload is invalid
      def self.load(payload)
        raise SerializationError, 'payload must be a Hash' unless payload.is_a?(Hash)

        strip_internal_metadata(normalize_hash(payload))
      end

      # Load a batch of serialized event payloads.
      #
      # @param payloads [Array<Hash>]
      # @return [Array<Hash>]
      def self.load_batch(payloads)
        raise SerializationError, 'payloads must be an Array' unless payloads.is_a?(Array)

        payloads.map { |payload| load(payload) }
      end

      # Load a serialized event payload into a CDC event when possible.
      #
      # @param payload [Hash]
      # @return [CDC::Core::ChangeEvent, Hash]
      def self.load_event(payload)
        return load_batch(payload).map { |item| load_event(item) } if payload.is_a?(Array)

        normalized = load(payload)
        return normalized unless change_event_payload?(normalized)

        build_change_event(normalized)
      end

      # Attach enqueue metadata without changing the event representation.
      #
      # @param payload [Hash]
      # @param metadata [Hash]
      # @return [Hash]
      def self.with_enqueue_metadata(payload, metadata)
        if payload.is_a?(Array)
          return payload.each_with_index.map do |child, index|
            with_enqueue_metadata(child, metadata_for_batch_item(metadata, index))
          end
        end

        normalized = normalize_hash(payload)
        normalized.merge(INTERNAL_METADATA_KEY => normalize_hash(metadata))
      end

      # Return cdc-solid-queue metadata from an enqueued payload.
      #
      # @param payload [Hash]
      # @return [Hash]
      def self.enqueue_metadata(payload)
        return enqueue_metadata_for_batch(payload) if payload.is_a?(Array)

        normalized = normalize_hash(payload)
        metadata = normalized[INTERNAL_METADATA_KEY]
        metadata.is_a?(Hash) ? metadata : {}
      end

      # Return the ordering value for a serialized event.
      #
      # @param payload [Hash]
      # @param key [Symbol]
      # @return [Object, nil]
      def self.ordering_value(payload, key)
        return payload.map { |item| ordering_value(item, key) } if payload.is_a?(Array)
        return nil if key == :none

        fetcher = ORDERING_VALUE_FETCHERS[key]
        return nil unless fetcher

        fetcher.call(load(payload))
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

      def self.build_change_event(normalized)
        CDC::Core::ChangeEvent.new(
          operation: normalized.fetch('operation'),
          schema: normalized.fetch('schema'),
          table: normalized.fetch('table'),
          old_values: normalized['old_values'],
          new_values: normalized['new_values'],
          primary_key: normalized['primary_key'],
          transaction_id: normalized['transaction_id'],
          commit_lsn: normalized['commit_lsn'],
          sequence_number: normalized['sequence_number'],
          occurred_at: normalized['occurred_at'],
          metadata: normalized['metadata'] || {}
        )
      end
      private_class_method :build_change_event

      def self.strip_internal_metadata(payload)
        payload.reject { |key, _value| key == INTERNAL_METADATA_KEY }
      end
      private_class_method :strip_internal_metadata

      def self.change_event_payload?(payload)
        payload.key?('operation') && payload.key?('schema') && payload.key?('table')
      end
      private_class_method :change_event_payload?

      def self.enqueue_metadata_for_batch(payloads)
        payloads.each_with_index.map do |payload, index|
          enqueue_metadata(payload).merge(
            'batch_size' => payloads.length,
            'batch_index' => index
          )
        end
      end
      private_class_method :enqueue_metadata_for_batch

      def self.metadata_for_batch_item(metadata, index)
        normalize_hash(metadata).merge(
          'batch_size' => normalize_hash(metadata).fetch('batch_size'),
          'batch_index' => index
        )
      end
      private_class_method :metadata_for_batch_item
    end
    # rubocop:enable Metrics/ClassLength
  end
end
