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
      captured_on: Date.new(2026, 3, 1)
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
  end

  test "upserts record for same character locale and date" do
    service = CollectionProgressTrackingService.new
    date = Date.new(2026, 3, 1)

    service.record!(
      name: "Cadamantis",
      locale: :en,
      snapshot: {
        character_idx: 1,
        collection_data: [{ "collections" => [{ "name" => "A" }] }],
        progress_data: { near: [{ name: "A" }], mid: [], low: [], below_one: [] }
      },
      captured_on: date
    )

    service.record!(
      name: "Cadamantis",
      locale: :en,
      snapshot: {
        character_idx: 1,
        collection_data: [{ "collections" => [{ "name" => "A" }, { "name" => "B" }] }],
        progress_data: { near: [], mid: [{ name: "B" }], low: [], below_one: [] }
      },
      captured_on: date
    )

    records = CollectionProgressSnapshot.for_character(1, :en)
    assert_equal 1, records.count
    assert_equal 2, records.first.total_collections
    assert_equal 1, records.first.completed_collections
  end

  test "returns limited history ordered by captured date descending" do
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
        captured_on: Date.new(2026, 3, 1) + index.days
      )
    end

    history = service.history_for(character_idx: 1, locale: :en, limit: 2)

    assert_equal 2, history.size
    assert_operator history.first.captured_on, :>, history.last.captured_on

    snapshot = service.snapshot_for(character_idx: 1, locale: :en, captured_on: Date.new(2026, 3, 3))
    previous = service.previous_snapshot_for(character_idx: 1, locale: :en, before: Date.new(2026, 3, 3))

    assert_not_nil snapshot
    assert_not_nil previous
    assert_equal Date.new(2026, 3, 2), previous.captured_on
  end
end
