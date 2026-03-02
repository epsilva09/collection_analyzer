require "test_helper"

class CollectTrackedCharactersSnapshotsJobTest < ActiveJob::TestCase
  test "collects snapshot for active tracked character" do
    tracked = TrackedCharacter.create!(
      character_name: "Cadamantis",
      character_idx: 75008,
      locale: "pt-BR",
      active: true,
      last_seen_at: Time.current
    )

    snapshot_service = Object.new
    snapshot_service.define_singleton_method(:call) do |_name, locale:, character_idx:|
      {
        character_idx: character_idx,
        collection_data: [ { "collections" => [ { "name" => "A" } ] } ],
        progress_data: { near: [ { name: "A", tier: "Tier", progress: 90, missing: 10, aggregated_materials: [] } ], mid: [], low: [], below_one: [] },
        top_materials: [],
        materials_by_bucket: {}
      }
    end

    tracking_service = Object.new
    recorded = []
    tracking_service.define_singleton_method(:record!) do |**args|
      recorded << args
    end

    original_snapshot_new = CollectionSnapshotService.method(:new)
    original_tracking_new = CollectionProgressTrackingService.method(:new)

    CollectionSnapshotService.define_singleton_method(:new) { |_args = {}| snapshot_service }
    CollectionProgressTrackingService.define_singleton_method(:new) { |_args = {}| tracking_service }

    begin
      CollectTrackedCharactersSnapshotsJob.perform_now
    ensure
      CollectionSnapshotService.define_singleton_method(:new, original_snapshot_new)
      CollectionProgressTrackingService.define_singleton_method(:new, original_tracking_new)
    end

    tracked.reload
    assert_equal 1, recorded.size
    assert tracked.last_snapshot_at.present?
  end
end
