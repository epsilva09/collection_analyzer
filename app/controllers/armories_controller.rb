class ArmoriesController < ApplicationController
  # percent at which an in-progress collection is considered "near completion".
  NEAR_COMPLETION_THRESHOLD = 80
  def index
    @name = params[:name].presence || "Cadamantis"
    client = ArmoryClient.new
    @error = nil
    @character_idx = nil
    @values = []
    @collection_data = []

    begin
      @character_idx = client.fetch_character_idx(@name)
      if @character_idx
        register_tracked_character!(name: @name, character_idx: @character_idx)
        details = client.fetch_collection_details(@character_idx)
        @collection_data = details[:data] || []
        @values = (details[:values] || []).map(&:to_s).map(&:strip)
      else
        @error = t("armories.errors.character_idx_not_found", name: @name)
      end
    rescue StandardError => e
      @error = localized_error_message(e)
    end

    # If we have values, normalize and prioritize special attributes for the index view
    if @values.present?
      annotated = @values.map { |v| annotate_value(v) }

      special_rows = annotated.select { |r| r[:is_special] }
      special_rows.sort_by! do |r|
        idx = special_attributes.find_index { |s| r[:parsed_key] == s }
        idx || special_attributes.length
      end

      regular_rows = annotated.reject { |r| r[:is_special] }

      @special_values = special_rows.map { |r| r[:raw] }
      @regular_values = regular_rows.map { |r| r[:raw] }
    else
      @special_values = []
      @regular_values = []
    end

    respond_to do |format|
      format.html
      format.json do
        render json: {
          name: @name,
          character_idx: @character_idx,
          values: @values,
          error: @error,
          special_values: @special_values,
          regular_values: @regular_values,
          collection_data: @collection_data
        }
      end
    end
  end

  def progress
    @name = params[:name].presence || "Cadamantis"
    @error = nil
    @progress_history = []

    begin
      snapshot = CollectionSnapshotService.new(
        near_completion_threshold: NEAR_COMPLETION_THRESHOLD
      ).call(@name)
      @character_idx = snapshot[:character_idx]
      @progress_data = snapshot[:progress_data]
      @top_materials = snapshot[:top_materials]
      @collection_data = snapshot[:collection_data]

      if @character_idx
        register_tracked_character!(name: @name, character_idx: @character_idx)
        progress_tracking_service = CollectionProgressTrackingService.new
        progress_tracking_service.record!(
          name: @name,
          locale: I18n.locale,
          snapshot: snapshot,
          captured_at: Time.current
        )

        @history_day = parse_history_day(params[:history_day])
        @history_hour = parse_history_hour(params[:history_hour])
        @history_visibility = normalize_history_visibility(params[:history_visibility])
        @progress_history = build_progress_history_rows(
          progress_tracking_service.history_for(
            character_idx: @character_idx,
            locale: I18n.locale,
            limit: 30,
            day: @history_day,
            hour: @history_hour,
            changed_only: @history_visibility != "all"
          )
        )
      else
        @error = t("armories.errors.character_idx_not_found", name: @name)
      end
    rescue StandardError => e
      @character_idx = nil
      @progress_data = ArmoryDefaults.empty_progress_data
      @top_materials = []
      @collection_data = []
      @progress_history = []
      @error = localized_error_message(e)
    end

    respond_to do |format|
      format.html
      format.json { render json: { name: @name, character_idx: @character_idx, progress: @progress_data, top_materials: @top_materials, error: @error } }
    end
  end

  def materials
    @name = params[:name].presence || "Cadamantis"
    @error = nil

    begin
      snapshot = CollectionSnapshotService.new(
        near_completion_threshold: NEAR_COMPLETION_THRESHOLD
      ).call(@name)
      @character_idx = snapshot[:character_idx]
      register_tracked_character!(name: @name, character_idx: @character_idx) if @character_idx
      @progress_data = snapshot[:progress_data]
      @top_materials = snapshot[:top_materials]
      @materials_by_bucket = snapshot[:materials_by_bucket]

      @error = t("armories.errors.character_idx_not_found", name: @name) unless @character_idx
    rescue StandardError => e
      @character_idx = nil
      @progress_data = ArmoryDefaults.empty_progress_data
      @top_materials = []
      @materials_by_bucket = ArmoryDefaults.empty_progress_data
      @error = localized_error_message(e)
    end

    respond_to do |format|
      format.html
      format.json { render json: { name: @name, character_idx: @character_idx, progress: @progress_data, bucket_materials: @materials_by_bucket, top_materials: @top_materials, error: @error } }
    end
  end

  def progress_changes
    @name = params[:name].presence || "Cadamantis"
    @character_idx = params[:character_idx].to_i
    @snapshot_id = params[:snapshot_id].to_i
    @change_type = normalize_change_type_filter(params[:change_type])
    @show_stable_materials = truthy_param?(params[:show_stable_materials])
    @error = nil

    tracking_service = CollectionProgressTrackingService.new
    @current_snapshot = tracking_service.snapshot_for(
      snapshot_id: @snapshot_id,
      character_idx: @character_idx,
      locale: I18n.locale
    )

    if @current_snapshot.blank?
      @error = t("armories.progress.changes.not_found")
      @changes = []
      return
    end

    @previous_snapshot = tracking_service.previous_snapshot_for(
      character_idx: @character_idx,
      locale: I18n.locale,
      before: snapshot_timestamp(@current_snapshot)
    )

    changes = build_collection_changes(
      @current_snapshot,
      @previous_snapshot,
      include_stable_materials: @show_stable_materials
    )
    @changes = filter_collection_changes(changes, change_type: @change_type)
  end

  def material_collections
    @name = params[:name].presence || "Cadamantis"
    @material_name = params[:material].to_s
    @bucket = params[:bucket].presence&.to_sym

    @error = nil

    begin
      snapshot = CollectionSnapshotService.new(
        near_completion_threshold: NEAR_COMPLETION_THRESHOLD
      ).call(@name)
      @character_idx = snapshot[:character_idx]
      register_tracked_character!(name: @name, character_idx: @character_idx) if @character_idx
      @progress_data = snapshot[:progress_data]

      @error = t("armories.errors.character_idx_not_found", name: @name) unless @character_idx
    rescue StandardError => e
      @character_idx = nil
      @progress_data = ArmoryDefaults.empty_progress_data
      @error = localized_error_message(e)
    end

    valid_buckets = %i[near mid low below_one]
    # For this view we always search all progress ranges so the user
    # can see every collection that still needs the chosen material.
    buckets_to_search = valid_buckets

    @collections_for_material = []

    if @material_name.present? && @error.blank?
      buckets_to_search.each do |bucket|
        (@progress_data[bucket] || []).each do |entry|
          next unless entry[:materials].present?

          mats_for_material = entry[:materials].select { |m| m[:name] == @material_name && m[:needed].to_i.positive? }
          next if mats_for_material.empty?

          total_needed = mats_for_material.sum { |m| m[:needed].to_i }

          @collections_for_material << {
            bucket: bucket,
            tier: entry[:tier],
            collection_name: entry[:name],
            progress: entry[:progress],
            missing: entry[:missing],
            needed: total_needed,
            rewards: entry[:rewards],
            status: entry[:status]
          }
        end
      end

      @collections_for_material.sort_by! do |col|
        [ -bucket_weight(col[:bucket]), -col[:progress].to_i ]
      end
    end

    respond_to do |format|
      format.html
      format.json do
        render json: {
          name: @name,
          character_idx: @character_idx,
          material: @material_name,
          bucket: @bucket,
          collections: @collections_for_material,
          error: @error
        }
      end
    end
  end

  # Compare collections of two characters by name.
  # Expects params[:name_a] and params[:name_b]
  def compare
    name_a = params[:name_a].presence
    name_b = params[:name_b].presence

    @error = nil
    compare_service = CompareCollectionsService.new
    @result = compare_service.empty_result(name_a, name_b)
    @comparison_ready = name_a.present? && name_b.present?

    begin
      compare_payload = compare_service.call(name_a: name_a, name_b: name_b)
      @comparison_ready = compare_payload[:comparison_ready]
      @result = compare_payload[:result]
    rescue StandardError => e
      @error = localized_error_message(e)
    end

    respond_to do |format|
      format.html
      format.json do
        render json: {
          result: @result,
          error: @error
        }
      end
    end
  end

  def compare_collections
    name_a = params[:name_a].presence
    name_b = params[:name_b].presence

    @error = nil
    compare_service = CompareCollectionsService.new
    @result = compare_service.empty_result(name_a, name_b)
    @comparison_ready = name_a.present? && name_b.present?

    begin
      compare_payload = compare_service.call(name_a: name_a, name_b: name_b)
      @comparison_ready = compare_payload[:comparison_ready]
      @result = compare_payload[:result]

      @collection_filter_name = params[:collection_name].to_s.strip
      @collection_filter_status = normalize_collection_compare_status_filter(params[:collection_status])
      @collection_filter_min_delta = parse_collection_compare_min_delta(params[:min_progress_delta])

      if @comparison_ready
        rows = Array(@result[:collection_comparison])
        @collection_comparison_total = rows.size
        @result[:collection_comparison] = filter_collection_comparison_rows(
          rows,
          collection_name: @collection_filter_name,
          status: @collection_filter_status,
          min_delta: @collection_filter_min_delta
        )
      else
        @collection_comparison_total = 0
      end
    rescue StandardError => e
      @error = localized_error_message(e)
      @collection_filter_name = ""
      @collection_filter_status = nil
      @collection_filter_min_delta = nil
      @collection_comparison_total = 0
    end

    respond_to do |format|
      format.html
      format.json do
        render json: {
          result: @result,
          error: @error
        }
      end
    end
  end

  private

  def bucket_weight(bucket)
    case bucket
    when :near then 3
    when :mid then 2
    when :low then 1
    else 0
    end
  end

  def special_attributes
    [
      "Perfuração",
      "PVE Perfuração",
      "Danos Críticos",
      "PVE Dano Crítico",
      "Aumentou todas as técnicas Amp.",
      "PVE Todas as Técnicas Amp",
      "Aumentou todos os ataques",
      "PVE Todos os Ataques"
    ]
  end

  def prefix_regex
    /\A\s*(PVE\s+)?Ignorar\s+/i
  end

  def annotate_value(raw)
    original = raw.to_s.strip
    had_ignore = !!(original =~ prefix_regex)
    cleaned = had_ignore ? original.sub(prefix_regex, "").strip : original

    parsed = AttributeParser.parse([ cleaned ]) rescue {}
    parsed_key = parsed.keys.first.to_s rescue cleaned

    is_special = false
    is_special = special_attributes.include?(parsed_key) unless had_ignore

    { raw: raw, cleaned: cleaned, parsed_key: parsed_key, is_special: is_special, had_ignore_prefix: had_ignore }
  end

  def localized_error_message(error)
    message = error.to_s

    if message.start_with?("Invalid JSON response:")
      detail = message.split(":", 2).last.to_s.strip
      t("armories.errors.invalid_json_response", detail: detail)
    elsif message.present?
      message
    else
      t("armories.errors.unexpected")
    end
  end

  def build_progress_history_rows(history)
    rows = history.to_a.sort_by(&:captured_at).reverse

    rows.each_with_index.map do |snapshot, index|
      previous_snapshot = rows[index + 1]

      {
        snapshot: snapshot,
        delta_completion_rate: previous_snapshot ? (snapshot.completion_rate.to_f - previous_snapshot.completion_rate.to_f).round(2) : nil,
        delta_completed_collections: previous_snapshot ? snapshot.completed_collections.to_i - previous_snapshot.completed_collections.to_i : nil
      }
    end
  end

  def filter_collection_changes(changes, change_type: nil)
    return changes if change_type.blank?

    changes.select { |change| change[:change_type].to_s == change_type }
  end

  def normalize_change_type_filter(value)
    normalized = value.to_s
    return nil if normalized.blank?

    return normalized if %w[added updated completed removed].include?(normalized)

    nil
  end

  def parse_history_day(value)
    return nil if value.blank?

    Date.iso8601(value.to_s)
  rescue ArgumentError
    nil
  end

  def parse_history_hour(value)
    return nil if value.blank?

    hour = value.to_i
    return hour if hour.between?(0, 23)

    nil
  end

  def normalize_history_visibility(value)
    normalized = value.to_s
    return "all" if normalized == "all"

    "changed"
  end

  def filter_collection_comparison_rows(rows, collection_name:, status:, min_delta:)
    filtered_rows = Array(rows)

    if collection_name.present?
      term = collection_name.downcase
      filtered_rows = filtered_rows.select do |row|
        row[:collection_name].to_s.downcase.include?(term) ||
          row[:tier].to_s.downcase.include?(term)
      end
    end

    if status.present?
      filtered_rows = filtered_rows.select do |row|
        collection_compare_status_match?(row, status)
      end
    end

    if min_delta.present?
      filtered_rows = filtered_rows.select do |row|
        row[:progress_diff].to_i.abs >= min_delta
      end
    end

    filtered_rows
  end

  def collection_compare_status_match?(row, status)
    case status
    when "completed_both"
      row[:done_a] && row[:done_b]
    when "completed_only_a"
      row[:done_a] && !row[:done_b]
    when "completed_only_b"
      row[:done_b] && !row[:done_a]
    when "pending_both"
      !row[:done_a] && !row[:done_b]
    else
      true
    end
  end

  def normalize_collection_compare_status_filter(value)
    normalized = value.to_s
    return nil if normalized.blank?

    allowed = %w[completed_both completed_only_a completed_only_b pending_both]
    allowed.include?(normalized) ? normalized : nil
  end

  def parse_collection_compare_min_delta(value)
    return nil if value.blank?

    numeric = value.to_i
    return nil if numeric.negative?

    numeric
  end

  def register_tracked_character!(name:, character_idx:)
    TrackedCharactersRegistryService.new.track!(
      name: name,
      character_idx: character_idx,
      locale: I18n.locale
    )
  rescue StandardError => e
    Rails.logger.warn("Failed to track character idx=#{character_idx}: #{e.message}")
  end

  def build_collection_changes(current_snapshot, previous_snapshot, include_stable_materials: false)
    current_entries = index_collections_payload(current_snapshot.collections_payload)
    previous_entries = index_collections_payload(previous_snapshot&.collections_payload)

    keys = (current_entries.keys + previous_entries.keys).uniq.sort

    keys.filter_map do |key|
      current = current_entries[key]
      previous = previous_entries[key]

      if previous.nil?
        {
          key: key,
          tier: current["tier"],
          name: current["name"],
          change_type: :added,
          inconsistent_progress: payload_truthy?(current["inconsistent_progress"]),
          from_progress: nil,
          to_progress: current["progress"],
          from_bucket: nil,
          to_bucket: current["bucket"],
          materials_delta: summarize_materials_delta({}, materials_index(current["materials"])),
          materials_stable: []
        }
      elsif current.nil?
        {
          key: key,
          tier: previous["tier"],
          name: previous["name"],
          change_type: :completed,
          inconsistent_progress: false,
          from_progress: previous["progress"],
          to_progress: 100,
          from_bucket: previous["bucket"],
          to_bucket: nil,
          materials_delta: summarize_materials_delta(materials_index(previous["materials"]), {}),
          materials_stable: []
        }
      else
        progress_changed = previous["progress"].to_i != current["progress"].to_i
        bucket_changed = previous["bucket"].to_s != current["bucket"].to_s

        previous_materials = materials_index(previous["materials"])
        current_materials = materials_index(current["materials"])
        materials_delta = summarize_materials_delta(previous_materials, current_materials)
        materials_stable = include_stable_materials ? summarize_stable_materials(previous_materials, current_materials) : []

        next unless progress_changed || bucket_changed || materials_delta.present?

        {
          key: key,
          tier: current["tier"],
          name: current["name"],
          change_type: :updated,
          inconsistent_progress: payload_truthy?(current["inconsistent_progress"]),
          from_progress: previous["progress"],
          to_progress: current["progress"],
          from_bucket: previous["bucket"],
          to_bucket: current["bucket"],
          materials_delta: materials_delta,
          materials_stable: materials_stable
        }
      end
    end
  end

  def index_collections_payload(payload)
    Array(payload).each_with_object({}) do |entry, indexed|
      key = entry["key"].to_s
      indexed[key] = entry if key.present?
    end
  end

  def materials_index(materials)
    Array(materials).each_with_object({}) do |material, indexed|
      name = material["name"].to_s
      next if name.blank?

      indexed[name] = material["needed"].to_i
    end
  end

  def summarize_materials_delta(previous_materials, current_materials)
    keys = (previous_materials.keys + current_materials.keys).uniq.sort

    keys.filter_map do |name|
      from = previous_materials[name].to_i
      to = current_materials[name].to_i
      delta = to - from
      next if delta.zero?

      { name: name, from: from, to: to, delta: delta }
    end
  end

  def summarize_stable_materials(previous_materials, current_materials)
    common_keys = previous_materials.keys & current_materials.keys

    common_keys.filter_map do |name|
      from = previous_materials[name].to_i
      to = current_materials[name].to_i
      next unless from.positive? && to == from

      { name: name, needed: to }
    end.sort_by { |entry| entry[:name].downcase }
  end

  def snapshot_timestamp(snapshot)
    if snapshot.respond_to?(:captured_at) && snapshot.captured_at.present?
      snapshot.captured_at
    else
      snapshot.captured_on.in_time_zone
    end
  end

  def payload_truthy?(value)
    value == true || value.to_s.casecmp("true").zero?
  end

  def truthy_param?(value)
    value == true || value.to_s == "1" || value.to_s.casecmp("true").zero?
  end
end
