# frozen_string_literal: true

require_relative '../../test_helper'

class EventSerializerTest < Minitest::Test
  Event = Data.define(:payload) do
    def to_h = payload
  end

  def test_dump_hash_normalizes_nested_keys
    payload = CDC::SolidQueue::EventSerializer.dump({ identity: { id: 1 }, values: [{ name: :ken }] })

    assert_equal({ 'identity' => { 'id' => 1 }, 'values' => [{ 'name' => :ken }] }, payload)
  end

  def test_dump_object_with_to_h
    payload = CDC::SolidQueue::EventSerializer.dump(Event.new({ table: 'users' }))

    assert_equal({ 'table' => 'users' }, payload)
  end

  def test_dump_rejects_unknown_object
    error = assert_raises(CDC::SolidQueue::SerializationError) { CDC::SolidQueue::EventSerializer.dump(Object.new) }
    assert_match(/to_h/, error.message)
  end

  def test_load_rejects_non_hash
    error = assert_raises(CDC::SolidQueue::SerializationError) { CDC::SolidQueue::EventSerializer.load([]) }
    assert_match(/Hash/, error.message)
  end

  def test_normalizes_unknown_leaf_to_string
    object = Object.new
    payload = CDC::SolidQueue::EventSerializer.dump(value: object)

    assert_equal object.to_s, payload.fetch('value')
  end

  def test_ordering_value_identity
    assert_equal 42, CDC::SolidQueue::EventSerializer.ordering_value({ identity: 42 }, :identity)
  end

  def test_ordering_value_primary_key_fallback
    assert_equal 7, CDC::SolidQueue::EventSerializer.ordering_value({ primary_key: 7 }, :identity)
    assert_equal 7, CDC::SolidQueue::EventSerializer.ordering_value({ primary_key: 7 }, :primary_key)
  end

  def test_ordering_value_relation
    assert_equal %w[public users],
                 CDC::SolidQueue::EventSerializer.ordering_value({ namespace: 'public', entity: 'users' }, :relation)
    assert_equal %w[public users],
                 CDC::SolidQueue::EventSerializer.ordering_value({ schema: 'public', table: 'users' }, :relation)
  end

  def test_ordering_value_transaction
    assert_equal 'tx1', CDC::SolidQueue::EventSerializer.ordering_value({ transaction_id: 'tx1' }, :transaction)
  end

  def test_ordering_value_global
    assert_equal '0/1', CDC::SolidQueue::EventSerializer.ordering_value({ source_position: '0/1' }, :global)
    assert_equal '0/2', CDC::SolidQueue::EventSerializer.ordering_value({ commit_lsn: '0/2' }, :global)
  end

  def test_ordering_value_none
    assert_nil CDC::SolidQueue::EventSerializer.ordering_value({ identity: 1 }, :none)
  end

  def test_enqueue_metadata_returns_empty_hash_for_plain_payload
    assert_equal({}, CDC::SolidQueue::EventSerializer.enqueue_metadata(id: 1))
  end
end

class EventSerializerAdditionalCoverageTest < Minitest::Test
  def test_ordering_value_unknown_key
    assert_nil CDC::SolidQueue::EventSerializer.ordering_value({ identity: 1 }, :unknown)
  end
end
