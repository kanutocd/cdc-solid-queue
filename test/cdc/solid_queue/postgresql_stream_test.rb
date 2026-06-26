# frozen_string_literal: true

require_relative '../../test_helper'

class PostgresqlStreamTest < Minitest::Test
  Metadata = Data.define(:wal_end_lsn, :server_time)

  FakeClientRunner = Struct.new(:payloads) do
    def start
      payloads.each do |payload|
        yield payload, Metadata.new('0/50', Time.utc(2026, 1, 1))
      end
    end
  end

  FakeRelationTracker = Struct.new(:messages) do
    def process(payload)
      messages.fetch(payload)
    end
  end

  FakeDecoder = Struct.new(:events) do
    def decode(message)
      events.fetch(message)
    end
  end

  FakeAdapter = Struct.new(:events) do
    def normalize(decoded)
      events.fetch(decoded)
    end
  end

  def test_each_yields_normalized_events
    event = change_event
    stream = stream_for(message: 'message', decoded: 'decoded', event: event)

    assert_equal [event], stream.each.to_a
  end

  def test_each_skips_decoder_nil_events
    stream = stream_for(message: 'message', decoded: nil, event: nil)

    assert_equal [], stream.each.to_a
  end

  def test_builds_default_pgoutput_client_runner_from_configuration
    config = CDC::SolidQueue::Configuration.new
    config.processor_job = Class.new { def self.perform_later(_payload) = :later }
    config.postgresql = {
      database_url: 'postgres://localhost/app',
      slot: 'slot',
      publication: 'publication',
      start_lsn: '0/0',
      auto_create_slot: true
    }

    stream = CDC::SolidQueue::PostgresqlStream.new(config)

    assert_instance_of Pgoutput::Client::Runner, stream.instance_variable_get(:@client_runner)
  end

  def test_builds_default_pgoutput_client_runner_from_alias_configuration
    config = CDC::SolidQueue::Configuration.new
    config.processor_job = Class.new { def self.perform_later(_payload) = :later }
    config.postgresql = {
      database_url: 'postgres://localhost/app',
      slot_name: 'slot',
      publication_names: ['publication']
    }

    stream = CDC::SolidQueue::PostgresqlStream.new(config)
    runner = stream.instance_variable_get(:@client_runner)

    assert_equal 'slot', runner.configuration.slot_name
    assert_equal ['publication'], runner.configuration.publication_names
  end

  def test_metadata_builder_returns_transport_metadata
    stream = stream_for(message: 'message', decoded: nil, event: nil)
    stream.instance_variable_set(:@transport_metadata, Metadata.new('0/60', Time.utc(2026, 1, 1)))

    assert_equal(
      { 'wal_end_lsn' => '0/60', 'server_time' => Time.utc(2026, 1, 1) },
      stream.send(:metadata_for, Object.new)
    )
  end

  def test_metadata_builder_returns_empty_hash_without_transport_metadata
    stream = stream_for(message: 'message', decoded: nil, event: nil)

    assert_equal({}, stream.send(:metadata_for, Object.new))
  end

  def test_metadata_value_returns_nil_for_missing_reader
    stream = stream_for(message: 'message', decoded: nil, event: nil)

    assert_nil stream.send(:metadata_value, Object.new, :wal_end_lsn)
  end

  private

  def stream_for(message:, decoded:, event:)
    config = CDC::SolidQueue::Configuration.new
    config.processor_job = Class.new { def self.perform_later(_payload) = :later }
    config.postgresql = { database_url: 'postgres://localhost/app', slot: 'slot', publication: 'publication' }

    CDC::SolidQueue::PostgresqlStream.new(
      config,
      client_runner: FakeClientRunner.new(['payload']),
      relation_tracker: FakeRelationTracker.new({ 'payload' => message }),
      decoder: FakeDecoder.new({ message => decoded }),
      adapter: FakeAdapter.new({ decoded => event })
    )
  end

  def change_event
    CDC::Core::ChangeEvent.new(operation: :insert, schema: 'public', table: 'users', new_values: { 'id' => 1 })
  end
end
