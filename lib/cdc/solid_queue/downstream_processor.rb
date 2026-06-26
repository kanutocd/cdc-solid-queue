# frozen_string_literal: true

module CDC
  module SolidQueue
    # Delegates processor-job work to CDC downstream runtime primitives.
    class DownstreamProcessor
      # @return [Configuration]
      attr_reader :configuration

      # @param configuration [Configuration]
      def initialize(configuration)
        @configuration = configuration
      end

      # Process one normalized CDC work item.
      #
      # @param item [Object, Array<Object>]
      # @return [Object]
      def process(item)
        return process_many(item) if item.is_a?(Array)

        process_one(item)
      end

      # Process many normalized CDC work items.
      #
      # @param items [Array<Object>]
      # @return [Object]
      def process_many(items)
        case configuration.downstream_runtime
        when :direct
          process_many_direct(items)
        when :concurrent
          process_with_runtime(concurrent_runtime, items)
        when :parallel
          process_with_runtime(parallel_runtime, items)
        else
          raise ConfigurationError, "unsupported downstream_runtime: #{configuration.downstream_runtime.inspect}"
        end
      end

      private

      def processor
        configuration.downstream_processor || raise(ConfigurationError, 'downstream_processor is required')
      end

      def process_one(item)
        case configuration.downstream_runtime
        when :direct
          processor.process(item)
        when :concurrent
          unwrap_single_result(process_with_runtime(concurrent_runtime, [item]))
        when :parallel
          unwrap_single_result(process_with_runtime(parallel_runtime, [item]))
        else
          raise ConfigurationError, "unsupported downstream_runtime: #{configuration.downstream_runtime.inspect}"
        end
      end

      def process_many_direct(items)
        return processor.process_many(items) if processor.respond_to?(:process_many)

        items.map { |item| processor.process(item) }
      end
      private :process_many_direct

      def process_with_runtime(runtime, items)
        runtime.process_many(items)
      ensure
        runtime.shutdown
      end

      def unwrap_single_result(result)
        result.is_a?(Array) && result.length == 1 ? result.first : result
      end
      private :unwrap_single_result

      def concurrent_runtime
        require_runtime('cdc/concurrent', 'cdc-concurrent') unless defined?(CDC::Concurrent::Runtime)
        CDC::Concurrent::Runtime.new(processor:, **configuration.downstream_options)
      rescue LoadError => e
        raise ConfigurationError, "cdc-concurrent is required for downstream_runtime :concurrent: #{e.message}"
      end

      def parallel_runtime
        require_runtime('cdc/parallel', 'cdc-parallel') unless defined?(CDC::Parallel::Runtime)
        CDC::Parallel::Runtime.new(processor:, **configuration.downstream_options)
      rescue LoadError => e
        raise ConfigurationError, "cdc-parallel is required for downstream_runtime :parallel: #{e.message}"
      end

      def require_runtime(feature, gem_name)
        require feature
      rescue LoadError
        raise LoadError, "install #{gem_name} and require #{feature}"
      end
    end
  end
end
