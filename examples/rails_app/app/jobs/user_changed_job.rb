# frozen_string_literal: true

# Example job that consumes normalized CDC events.
class UserChangedJob < ApplicationJob
  include CDC::SolidQueue::ProcessorJob

  def process(event)
    Rails.logger.info(
      "cdc event #{event.operation} #{event.qualified_table_name} primary_key=#{event.primary_key.inspect}"
    )
  end
end
