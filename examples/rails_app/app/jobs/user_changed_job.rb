# frozen_string_literal: true

# Example job that hands normalized CDC events to configured downstream runtimes.
class UserChangedJob < ApplicationJob
  include CDC::SolidQueue::ProcessorJob
end
