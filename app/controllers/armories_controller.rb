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

    begin
      snapshot = CollectionSnapshotService.new(
        near_completion_threshold: NEAR_COMPLETION_THRESHOLD
      ).call(@name)
      @character_idx = snapshot[:character_idx]
      @progress_data = snapshot[:progress_data]
      @top_materials = snapshot[:top_materials]
      @collection_data = snapshot[:collection_data]

      @error = t("armories.errors.character_idx_not_found", name: @name) unless @character_idx
    rescue StandardError => e
      @character_idx = nil
      @progress_data = { near: [], mid: [], low: [], below_one: [] }
      @top_materials = []
      @collection_data = []
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
      @progress_data = snapshot[:progress_data]
      @top_materials = snapshot[:top_materials]
      @materials_by_bucket = snapshot[:materials_by_bucket]

      @error = t("armories.errors.character_idx_not_found", name: @name) unless @character_idx
    rescue StandardError => e
      @character_idx = nil
      @progress_data = { near: [], mid: [], low: [], below_one: [] }
      @top_materials = []
      @materials_by_bucket = { near: [], mid: [], low: [], below_one: [] }
      @error = localized_error_message(e)
    end

    respond_to do |format|
      format.html
      format.json { render json: { name: @name, character_idx: @character_idx, progress: @progress_data, bucket_materials: @materials_by_bucket, top_materials: @top_materials, error: @error } }
    end
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
      @progress_data = snapshot[:progress_data]

      @error = t("armories.errors.character_idx_not_found", name: @name) unless @character_idx
    rescue StandardError => e
      @character_idx = nil
      @progress_data = { near: [], mid: [], low: [], below_one: [] }
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
end
