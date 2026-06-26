# frozen_string_literal: true

require_relative '../../test_helper'

class CheckpointTest < Minitest::Test
  Result = Data.define(:checkpoint_position)

  def test_advance_uses_source_position
    checkpoint = CDC::SolidQueue::Checkpoint.new

    assert_equal '0/10', checkpoint.advance(source_position: '0/10')
    assert_equal '0/10', checkpoint.position
  end

  def test_advance_uses_commit_lsn
    checkpoint = CDC::SolidQueue::Checkpoint.new

    assert_equal '0/20', checkpoint.advance(commit_lsn: '0/20')
    assert_equal '0/20', checkpoint.position
  end

  def test_advance_uses_event_metadata_wal_end_lsn
    checkpoint = CDC::SolidQueue::Checkpoint.new

    assert_equal '0/30', checkpoint.advance(metadata: { wal_end_lsn: '0/30' })
    assert_equal '0/30', checkpoint.position
  end

  def test_advance_falls_back_to_result_position
    checkpoint = CDC::SolidQueue::Checkpoint.new

    assert_equal '0/40', checkpoint.advance(Object.new, Result.new('0/40'))
    assert_equal '0/40', checkpoint.position
  end
end
