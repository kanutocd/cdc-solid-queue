# frozen_string_literal: true

require 'pgoutput_client'
require 'pgoutput'
require 'pgoutput/decoder'
require 'pgoutput/source_adapter'

module CDC
  module SolidQueue
    # Enumerable stream that normalizes PostgreSQL pgoutput payloads into CDC events.
    class PostgresqlStream
      # @param configuration [Configuration]
      # @param client_runner [Object, nil]
      # @param relation_tracker [Object]
      # @param decoder [Object]
      # @param adapter [Object, nil]
      def initialize(configuration, client_runner: nil, relation_tracker: Pgoutput::RelationTracker.new,
                     decoder: Pgoutput::Decoder.new, adapter: nil)
        @configuration = configuration
        @client_runner = client_runner || build_client_runner
        @relation_tracker = relation_tracker
        @decoder = decoder
        @adapter = adapter || build_adapter
        @transport_metadata = nil
      end

      # Stream normalized CDC::Core::ChangeEvent instances.
      #
      # @yieldparam event [CDC::Core::ChangeEvent]
      # @return [void]
      def each
        return enum_for(:each) unless block_given?

        @client_runner.start do |payload, metadata|
          @transport_metadata = metadata
          event = normalize(payload)
          yield event unless event.nil?
        ensure
          @transport_metadata = nil
        end
      end

      private

      def build_client_runner
        Pgoutput::Client::Runner.new(**postgresql_options)
      end

      def postgresql_options
        settings = @configuration.postgresql
        {
          database_url: settings.fetch(:database_url) { ENV.fetch('DATABASE_URL') },
          slot_name: settings.fetch(:slot) { settings.fetch(:slot_name) },
          publication_names: settings.fetch(:publication) { settings.fetch(:publication_names) },
          start_lsn: settings[:start_lsn],
          auto_create_slot: @configuration.auto_create_slot || settings.fetch(:auto_create_slot, false),
          temporary_slot: settings.fetch(:temporary_slot, false),
          binary: settings.fetch(:binary, false),
          messages: settings.fetch(:messages, false)
        }.compact
      end

      def build_adapter
        Pgoutput::SourceAdapter::Cdc.new(metadata_builder: method(:metadata_for))
      end

      def normalize(payload)
        message = @relation_tracker.process(payload)
        decoded = @decoder.decode(message)
        return nil if decoded.nil?

        @adapter.normalize(decoded)
      end

      def metadata_for(_event)
        metadata = @transport_metadata
        return {} if metadata.nil?

        {
          'wal_end_lsn' => metadata_value(metadata, :wal_end_lsn),
          'server_time' => metadata_value(metadata, :server_time)
        }.compact
      end

      def metadata_value(metadata, name)
        metadata.public_send(name) if metadata.respond_to?(name)
      end
    end
  end
end
