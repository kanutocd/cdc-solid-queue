# frozen_string_literal: true

module CDC
  module SolidQueue
    # Runtime configuration for PostgreSQL CDC ingestion into Solid Queue.
    #
    # The configuration object is intentionally small in the first release. It
    # describes the target job class, Solid Queue queue name, ordering behavior,
    # and PostgreSQL replication settings.
    class Configuration
      # The only CDC source supported by the initial implementation.
      SUPPORTED_SOURCE = :postgresql
      # Supported ordering scopes for serialized CDC events.
      ORDERING_KEYS = %i[identity primary_key relation transaction global none].freeze
      # Supported downstream execution runtimes for processor jobs.
      DOWNSTREAM_RUNTIMES = %i[concurrent parallel direct].freeze

      attr_accessor :processor_job, :queue, :preserve_order, :ordering_key, :postgresql, :checkpoint,
                    :downstream_processor, :downstream_runtime, :downstream_options

      # Build a configuration with safe defaults.
      def initialize
        @processor_job = nil
        @queue = 'cdc'
        @preserve_order = true
        @ordering_key = :identity
        @postgresql = {}
        @checkpoint = Checkpoint.new
        @downstream_processor = nil
        @downstream_runtime = :concurrent
        @downstream_options = {}
      end

      # Validate this configuration.
      #
      # @return [true]
      # @raise [ConfigurationError] if required values are missing
      # @raise [UnsupportedSourceError] if a non-PostgreSQL source is supplied
      # rubocop:disable Naming/PredicateMethod
      def validate!
        validate_processor_job!
        validate_queue!
        validate_ordering_key!
        validate_postgresql!
        validate_checkpoint!
        validate_downstream!
        true
      end
      # rubocop:enable Naming/PredicateMethod

      # Return a normalized source name.
      #
      # @return [Symbol]
      def source
        configured = @postgresql.fetch(:source, SUPPORTED_SOURCE)
        configured.to_sym
      end

      private

      def validate_processor_job!
        return if @processor_job.respond_to?(:perform_later) || @processor_job.respond_to?(:perform_now)

        raise ConfigurationError, 'processor_job must respond to perform_later or perform_now'
      end

      def validate_queue!
        return if @queue.is_a?(String) && !@queue.empty?

        raise ConfigurationError, 'queue must be a non-empty String'
      end

      def validate_ordering_key!
        return if ORDERING_KEYS.include?(@ordering_key)

        raise ConfigurationError, "ordering_key must be one of: #{ORDERING_KEYS.join(', ')}"
      end

      def validate_postgresql!
        raise UnsupportedSourceError, 'cdc-solid-queue supports only PostgreSQL' unless source == SUPPORTED_SOURCE
        return unless @postgresql.empty?

        raise ConfigurationError, 'postgresql settings are required'
      end

      def validate_checkpoint!
        return if @checkpoint.nil? || @checkpoint.respond_to?(:advance)

        raise ConfigurationError, 'checkpoint must respond to advance'
      end

      def validate_downstream!
        unless DOWNSTREAM_RUNTIMES.include?(@downstream_runtime)
          raise ConfigurationError, "downstream_runtime must be one of: #{DOWNSTREAM_RUNTIMES.join(', ')}"
        end

        return if @downstream_processor.nil? || @downstream_processor.respond_to?(:process)

        raise ConfigurationError, 'downstream_processor must respond to process'
      end
    end
  end
end
