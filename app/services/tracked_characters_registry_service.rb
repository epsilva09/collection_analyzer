class TrackedCharactersRegistryService
  def initialize(scope: TrackedCharacter)
    @scope = scope
  end

  def track!(name:, character_idx:, locale:)
    normalized_idx = character_idx.to_i
    return if normalized_idx <= 0

    record = @scope.find_or_initialize_by(character_idx: normalized_idx)
    record.assign_attributes(
      character_name: name.to_s.strip,
      locale: locale.to_s,
      active: true,
      last_seen_at: Time.current
    )
    record.save!
    record
  end
end
