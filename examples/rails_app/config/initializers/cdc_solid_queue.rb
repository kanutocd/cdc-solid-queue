# frozen_string_literal: true

CDC::SolidQueue.configure do |config|
  config.processor_job = UserChangedJob
  config.queue = 'cdc'
  config.preserve_order = true
  config.ordering_key = :primary_key
  config.checkpoint = CDC::SolidQueue::Checkpoint.new
  config.postgresql = {
    database_url: ENV.fetch('DATABASE_URL'),
    slot: ENV.fetch('CDC_SLOT', 'cdc_solid_queue'),
    publication: ENV.fetch('CDC_PUBLICATION', 'cdc_publication'),
    auto_create_slot: ENV.fetch('CDC_AUTO_CREATE_SLOT', 'false') == 'true'
  }
end
