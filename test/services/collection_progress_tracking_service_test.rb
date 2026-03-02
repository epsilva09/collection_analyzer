require "test_helper"

class CollectionProgressTrackingServiceTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "records a daily snapshot with computed completion metrics" do
    snapshot = {
      character_idx: 75008,
      collection_data: [
        { "collections" => [ { "name" => "A" }, { "name" => "B" } ] },
        { "collections" => [ { "name" => "C" }, { "name" => "D" } ] }
      ],
      progress_data: {
        near: [ { name: "Near" } ],
        mid: [ { name: "Mid" } ],
        low: [ { name: "Low" } ],
        below_one: []
      }
    }

    record = CollectionProgressTrackingService.new.record!(
      name: "Cadamantis",
      locale: :"pt-BR",
      snapshot: snapshot,
      captured_at: Time.zone.parse("2026-03-01 10:00")
    )

    assert_equal 75008, record.character_idx
    assert_equal 4, record.total_collections
    assert_equal 1, record.completed_collections
    assert_equal 25.0, record.completion_rate.to_f
    assert_equal 1, record.near_count
    assert_equal 1, record.mid_count
    assert_equal 1, record.low_count
    assert_equal 0, record.below_one_count
    assert record.collections_payload.present?
    payload_buckets = record.collections_payload.map { |entry| entry["bucket"] }
    assert_includes payload_buckets, "near"
    assert record.collections_payload.all? { |entry| entry["key"].present? }
    assert_equal true, record.has_changes
    assert_operator record.changes_count, :>, 0
  end

  test "marks snapshot as unchanged when payload matches previous snapshot" do
    service = CollectionProgressTrackingService.new
    first_captured_at = Time.zone.parse("2026-03-01 10:15")
    second_captured_at = Time.zone.parse("2026-03-01 10:16")

    service.record!(
      name: "Cadamantis",
      locale: :en,
      snapshot: {
        character_idx: 1,
        collection_data: [{ "collections" => [{ "name" => "A" }] }],
        progress_data: { near: [{ name: "A" }], mid: [], low: [], below_one: [] }
      },
      captured_at: first_captured_at
    )

    second = service.record!(
      name: "Cadamantis",
      locale: :en,
      snapshot: {
        character_idx: 1,
        collection_data: [{ "collections" => [{ "name" => "A" }] }],
        progress_data: { near: [{ name: "A" }], mid: [], low: [], below_one: [] }
      },
      captured_at: second_captured_at
    )

    records = CollectionProgressSnapshot.for_character(1, :en)
    assert_equal 2, records.count
    assert_equal 1, second.total_collections
    assert_equal 0, second.completed_collections
    assert_equal false, second.has_changes
    assert_equal 0, second.changes_count
  end

  test "returns limited history ordered by captured time descending" do
    service = CollectionProgressTrackingService.new

    3.times do |index|
      service.record!(
        name: "Cadamantis",
        locale: :en,
        snapshot: {
          character_idx: 1,
          collection_data: [{ "collections" => [{ "name" => "A" }] }],
          progress_data: { near: [ { name: "N#{index}" } ], mid: [], low: [], below_one: [] }
        },
        captured_at: Time.zone.parse("2026-03-0#{index + 1} 0#{index}:00")
      )
    end

    history = service.history_for(character_idx: 1, locale: :en, limit: 2, hour: 2)

    assert_equal 1, history.size
    assert_equal 2, history.first.captured_at.hour

    snapshot = service.snapshot_for(snapshot_id: CollectionProgressSnapshot.for_character(1, :en).order(captured_at: :desc).first.id, character_idx: 1, locale: :en)
    previous = service.previous_snapshot_for(character_idx: 1, locale: :en, before: snapshot.captured_at)

    assert_not_nil snapshot
    assert_not_nil previous
    assert_operator previous.captured_at, :<, snapshot.captured_at

    changed_only_history = service.history_for(character_idx: 1, locale: :en, limit: 10, changed_only: true)
    assert changed_only_history.all?(&:has_changes)
  end
end
