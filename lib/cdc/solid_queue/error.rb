# frozen_string_literal: true

module CDC
  module SolidQueue
    # Base error for all cdc-solid-queue failures.
    class Error < StandardError; end

    # Raised when configuration is missing or invalid.
    class ConfigurationError < Error; end

    # Raised when an unsupported source is configured.
    class UnsupportedSourceError < ConfigurationError; end

    # Raised when an event cannot be serialized for job execution.
    class SerializationError < Error; end
  end
end
