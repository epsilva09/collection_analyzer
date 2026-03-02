class CollectionProgressTrackingService
  def initialize(scope: CollectionProgressSnapshot)
    @scope = scope
  end

  def record!(name:, locale:, snapshot:, captured_at: Time.current)
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
    total_collections = [ total_collections_from_payload, in_progress_count ].max
    completed_collections = [ total_collections - in_progress_count, 0 ].max

    completion_rate = if total_collections.positive?
      ((completed_collections.to_f / total_collections) * 100.0).round(2)
    else
      0.0
    end

    rounded_captured_at = captured_at.change(sec: 0)
    captured_on = rounded_captured_at.to_date
    supports_captured_at = @scope.column_names.include?("captured_at")

    identity = {
      character_idx: character_idx,
      locale: locale.to_s
    }
    identity[supports_captured_at ? :captured_at : :captured_on] = supports_captured_at ? rounded_captured_at : captured_on

    record = @scope.find_or_initialize_by(identity)

    attrs = {
      character_name: name.to_s.strip,
      character_idx: character_idx,
      captured_on: captured_on,
      total_collections: total_collections,
      completed_collections: completed_collections,
      near_count: near_count,
      mid_count: mid_count,
      low_count: low_count,
      below_one_count: below_one_count,
      completion_rate: completion_rate,
      collections_payload: build_collections_payload(progress_data)
    }
    attrs[:captured_at] = rounded_captured_at if supports_captured_at

    previous_snapshot = previous_snapshot_for(
      character_idx: character_idx,
      locale: locale,
      before: supports_captured_at ? rounded_captured_at : captured_on
    )

    change_metrics = classify_changes(
      current_payload: attrs[:collections_payload],
      previous_payload: previous_snapshot&.collections_payload
    )

    if @scope.column_names.include?("has_changes")
      attrs[:has_changes] = change_metrics[:changed]
      attrs[:changes_count] = change_metrics[:changes_count]
    end

    record.assign_attributes(attrs)

    record.save!
    record
  end

  def history_for(character_idx:, locale:, limit: 14, day: nil, hour: nil, changed_only: nil)
    supports_captured_at = @scope.column_names.include?("captured_at")
    relation = @scope
      .for_character(character_idx, locale)
      .order(supports_captured_at ? { captured_at: :desc } : { captured_on: :desc })

    relation = relation.for_day(day) if day.present?
    relation = relation.for_hour(hour) if hour.present? && supports_captured_at
    relation = relation.changed_only if changed_only == true && @scope.column_names.include?("has_changes")

    relation.limit(limit)
  end

  def snapshot_for(snapshot_id:, character_idx:, locale:)
    @scope.find_by(
      id: snapshot_id.to_i,
      character_idx: character_idx.to_i,
      locale: locale.to_s
    )
  end

  def previous_snapshot_for(character_idx:, locale:, before:)
    supports_captured_at = @scope.column_names.include?("captured_at")
    @scope
      .for_character(character_idx, locale)
      .where(supports_captured_at ? "captured_at < ?" : "captured_on < ?", before)
      .order(supports_captured_at ? { captured_at: :desc } : { captured_on: :desc })
      .first
  end

  private

  def build_collections_payload(progress_data)
    progress_data.to_h.flat_map do |bucket, entries|
      Array(entries).map do |entry|
        {
          key: entry_key(entry),
          tier: entry[:tier].to_s,
          name: entry[:name].to_s,
          bucket: bucket.to_s,
          progress: entry[:progress].to_i,
          missing: entry[:missing].to_i,
          materials: Array(entry[:aggregated_materials]).map do |material|
            {
              name: material[:name].to_s,
              needed: material[:needed].to_i
            }
          end.sort_by { |material| material[:name].downcase }
        }
      end
    end.sort_by { |entry| entry[:key] }
  end

  def entry_key(entry)
    [ entry[:tier].to_s.strip, entry[:name].to_s.strip ].join("::")
  end

  def extract_total_collections(collection_data)
    Array(collection_data).sum do |tier|
      collections = tier.is_a?(Hash) ? tier["collections"] : nil
      collections.is_a?(Array) ? collections.size : 0
    end
  end

  def classify_changes(current_payload:, previous_payload:)
    return { changed: true, changes_count: Array(current_payload).size } if previous_payload.blank?

    current_by_key = index_payload_by_key(current_payload)
    previous_by_key = index_payload_by_key(previous_payload)
    keys = (current_by_key.keys + previous_by_key.keys).uniq

    changes_count = keys.count do |key|
      current_by_key[key] != previous_by_key[key]
    end

    {
      changed: changes_count.positive?,
      changes_count: changes_count
    }
  end

  def index_payload_by_key(payload)
    Array(payload).each_with_object({}) do |entry, memo|
      normalized_entry = normalize_payload_entry(entry)
      key = normalized_entry["key"].to_s
      memo[key] = normalized_entry if key.present?
    end
  end

  def normalize_payload_entry(entry)
    raw = entry.respond_to?(:to_h) ? entry.to_h : {}
    materials = Array(raw["materials"] || raw[:materials]).map do |material|
      material_hash = material.respond_to?(:to_h) ? material.to_h : {}
      {
        "name" => (material_hash["name"] || material_hash[:name]).to_s,
        "needed" => (material_hash["needed"] || material_hash[:needed]).to_i
      }
    end.sort_by { |material| material["name"].downcase }

    {
      "key" => (raw["key"] || raw[:key]).to_s,
      "tier" => (raw["tier"] || raw[:tier]).to_s,
      "name" => (raw["name"] || raw[:name]).to_s,
      "bucket" => (raw["bucket"] || raw[:bucket]).to_s,
      "progress" => (raw["progress"] || raw[:progress]).to_i,
      "missing" => (raw["missing"] || raw[:missing]).to_i,
      "materials" => materials
    }
  end
end
