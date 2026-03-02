class CollectionProgressTrackingService
  def initialize(scope: CollectionProgressSnapshot)
    @scope = scope
  end

  def record!(name:, locale:, snapshot:, captured_on: Time.zone.today)
    return nil if snapshot.blank?

    character_idx = snapshot[:character_idx].to_i
    return nil unless character_idx.positive?

    progress_data = snapshot[:progress_data] || ArmoryDefaults.empty_progress_data

    near_count = (progress_data[:near] || []).size
    mid_count = (progress_data[:mid] || []).size
    low_count = (progress_data[:low] || []).size
    below_one_count = (progress_data[:below_one] || []).size

    in_progress_count = near_count + mid_count + low_count + below_one_count

    total_collections_from_payload = extract_total_collections(snapshot[:collection_data])
    total_collections = [total_collections_from_payload, in_progress_count].max
    completed_collections = [total_collections - in_progress_count, 0].max

    completion_rate = if total_collections.positive?
      ((completed_collections.to_f / total_collections) * 100.0).round(2)
    else
      0.0
    end

    record = @scope.find_or_initialize_by(
      character_idx: character_idx,
      locale: locale.to_s,
      captured_on: captured_on
    )

    record.assign_attributes(
      character_name: name.to_s.strip,
      character_idx: character_idx,
      total_collections: total_collections,
      completed_collections: completed_collections,
      near_count: near_count,
      mid_count: mid_count,
      low_count: low_count,
      below_one_count: below_one_count,
      completion_rate: completion_rate
    )

    record.save!
    record
  end

  def history_for(character_idx:, locale:, limit: 14)
    @scope
      .for_character(character_idx, locale)
      .order(captured_on: :desc)
      .limit(limit)
  end

  private

  def extract_total_collections(collection_data)
    Array(collection_data).sum do |tier|
      collections = tier.is_a?(Hash) ? tier["collections"] : nil
      collections.is_a?(Array) ? collections.size : 0
    end
  end
end
