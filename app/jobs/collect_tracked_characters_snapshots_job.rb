class CollectTrackedCharactersSnapshotsJob < ApplicationJob
  queue_as :default

  def perform
    snapshot_service = CollectionSnapshotService.new
    tracking_service = CollectionProgressTrackingService.new

    TrackedCharacter.active.find_each do |tracked_character|
      collect_for_character(
        tracked_character: tracked_character,
        snapshot_service: snapshot_service,
        tracking_service: tracking_service
      )
    end
  end

  private

  def collect_for_character(tracked_character:, snapshot_service:, tracking_service:)
    snapshot = snapshot_service.call(
      tracked_character.character_name,
      locale: tracked_character.locale,
      character_idx: tracked_character.character_idx
    )
    return unless snapshot[:character_idx].to_i.positive?

    tracking_service.record!(
      name: tracked_character.character_name,
      locale: tracked_character.locale,
      snapshot: snapshot,
      captured_at: Time.current
    )

    tracked_character.update!(last_snapshot_at: Time.current)
  rescue StandardError => e
    Rails.logger.error("CollectTrackedCharactersSnapshotsJob failed for idx=#{tracked_character.character_idx}: #{e.message}")
  end
end
