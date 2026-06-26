# frozen_string_literal: true

require 'cdc/core'
require 'cdc/concurrent'

# Example I/O-oriented CDC processor executed through cdc-concurrent.
class WebhookProcessor < CDC::Core::Processor
  concurrent_safe!

  def process(event)
    Rails.logger.info(
      "downstream cdc event #{event.operation} #{event.qualified_table_name} primary_key=#{event.primary_key.inspect}"
    )
    CDC::Core::ProcessorResult.success(event)
  end

  def process_many(events)
    events.map { |event| process(event) }
  end
end
