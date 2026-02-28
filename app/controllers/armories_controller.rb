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
    snapshot = build_progress_snapshot(@name)
    @character_idx = snapshot[:character_idx]
    @progress_data = snapshot[:progress_data]
    @top_materials = snapshot[:top_materials]
    @collection_data = snapshot[:collection_data]
    @error = snapshot[:error]

    respond_to do |format|
      format.html
      format.json { render json: { name: @name, character_idx: @character_idx, progress: @progress_data, top_materials: @top_materials, error: @error } }
    end
  end

  def materials
    @name = params[:name].presence || "Cadamantis"
    snapshot = build_progress_snapshot(@name)
    @character_idx = snapshot[:character_idx]
    @progress_data = snapshot[:progress_data]
    @top_materials = snapshot[:top_materials]
    @materials_by_bucket = snapshot[:materials_by_bucket]
    @error = snapshot[:error]

    respond_to do |format|
      format.html
      format.json { render json: { name: @name, character_idx: @character_idx, progress: @progress_data, bucket_materials: @materials_by_bucket, top_materials: @top_materials, error: @error } }
    end
  end

  # Compare collections of two characters by name.
  # Expects params[:name_a] and params[:name_b]
  def compare
    name_a = params[:name_a].presence
    name_b = params[:name_b].presence

    @comparison_ready = name_a.present? && name_b.present?

    client = ArmoryClient.new
    @error = nil
    @result = {
      name_a: name_a,
      name_b: name_b,
      character_idx_a: nil,
      character_idx_b: nil,
      values_a: [],
      values_b: [],
      common: [],
      only_a: [],
      only_b: []
    }

    begin
      if @comparison_ready
        @result[:character_idx_a] = client.fetch_character_idx(name_a)
        @result[:character_idx_b] = client.fetch_character_idx(name_b)

        if @result[:character_idx_a]
          details = client.fetch_collection_details(@result[:character_idx_a])
          @result[:values_a] = (details[:values] || []).map(&:to_s).map(&:strip)
          @result[:collection_data_a] = details[:data] || []
        end

        if @result[:character_idx_b]
          details = client.fetch_collection_details(@result[:character_idx_b])
          @result[:values_b] = (details[:values] || []).map(&:to_s).map(&:strip)
          @result[:collection_data_b] = details[:data] || []
        end

        # Parse attributes into structured numeric values
        parsed_a = AttributeParser.parse(@result[:values_a])
        parsed_b = AttributeParser.parse(@result[:values_b])

        keys = (parsed_a.keys | parsed_b.keys).to_a.sort

        detailed = keys.map do |k|
          a = parsed_a[k] || { value: 0.0, unit: nil, raw: nil }
          b = parsed_b[k] || { value: 0.0, unit: nil, raw: nil }
          unit = (a[:unit] == b[:unit]) ? a[:unit] || b[:unit] : :mixed
          val_a = a[:value] || 0.0
          val_b = b[:value] || 0.0
          diff = (val_a - val_b)
          { attribute: k, value_a: val_a, value_b: val_b, unit: unit, diff: diff, raw_a: a[:raw], raw_b: b[:raw] }
        end

        @result[:detailed] = detailed
        # Annotate rows with a cleaned attribute and is_special flag, then order using shared helpers
        annotated = detailed.map do |row|
          meta = annotate_value(row[:attribute])
          row.merge(cleaned_attribute: meta[:cleaned], parsed_key: meta[:parsed_key], is_special: meta[:is_special], had_ignore_prefix: meta[:had_ignore_prefix])
        end

        special_rows = annotated.select { |r| r[:is_special] }
        # Sort special rows according to the shared special_attributes order
        special_rows.sort_by! do |r|
          idx = special_attributes.find_index { |s| r[:parsed_key] == s }
          idx || special_attributes.length
        end

        regular_rows = annotated.reject { |r| r[:is_special] }

        @result[:detailed_ordered] = special_rows + regular_rows
        @result[:common] = (parsed_a.keys & parsed_b.keys).to_a.sort
        @result[:only_a] = (parsed_a.keys - parsed_b.keys).to_a.sort
        @result[:only_b] = (parsed_b.keys - parsed_a.keys).to_a.sort

        # Provide annotated versions for use in the view (preserve original strings)
        @result[:common_annotated] = @result[:common].map { |item| annotate_value(item) }
        @result[:only_a_annotated] = @result[:only_a].map { |item| annotate_value(item) }
        @result[:only_b_annotated] = @result[:only_b].map { |item| annotate_value(item) }
      end
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

  def build_progress_snapshot(name)
    client = ArmoryClient.new
    error = nil
    character_idx = nil
    progress_data = { near: [], mid: [], low: [], below_one: [] }
    collection_data = []

    begin
      character_idx = client.fetch_character_idx(name)
      if character_idx
        details = client.fetch_collection_details(character_idx)
        collection_data = details[:data] || []

        collection_data.each do |tier|
          next unless tier.is_a?(Hash) && tier["collections"].is_a?(Array)

          tier["collections"].each do |col|
            prog = col["progress"].to_i
            next unless prog >= 0 && prog < 100

            missing = 100 - prog
            rewards_raw = col["rewards"] || []

            rewards = rewards_raw.map.with_index do |reward, index|
              unlocked = if reward.key?("applied")
                           !!reward["applied"]
              else
                           total_rewards = rewards_raw.size
                           threshold = if total_rewards == 3
                                         [ 30, 60, 100 ][index] || 100
                           elsif total_rewards.positive?
                                         (((index + 1) * 100.0) / total_rewards).round
                           else
                                         100
                           end
                           prog >= threshold
              end

              {
                description: reward["description"].to_s,
                unlocked: unlocked
              }
            end

            status = rewards.map { |r| r[:description] }.join(", ")

            materials = []

            if col["data"].is_a?(Array)
              col["data"].each do |m|
                m_progress = m["progress"].to_i
                m_max = m["max"].to_i
                needed = m_max - m_progress
                if needed > 0
                  materials << { name: m["name"], needed: needed, mission: nil, current: m_progress, max: m_max }
                end
              end
            end

            if col["missions"].is_a?(Array)
              col["missions"].each do |mission|
                mission_name = mission["name"] || mission["title"]
                (mission["data"] || []).each do |m|
                  m_progress = m["progress"].to_i
                  m_max = m["max"].to_i
                  needed = m_max - m_progress
                  if needed > 0
                    materials << { name: m["name"], needed: needed, mission: mission_name, current: m_progress, max: m_max }
                  end
                end
              end
            end

            entry = {
              tier: tier["name"],
              name: col["name"],
              progress: prog,
              missing: missing,
              status: status,
              rewards: rewards,
              materials: materials
            }

            if prog < 1
              progress_data[:below_one] << entry
            elsif prog <= 29
              progress_data[:low] << entry
            elsif prog <= 59
              progress_data[:mid] << entry
            elsif prog >= NEAR_COMPLETION_THRESHOLD
              progress_data[:near] << entry
            end
          end
        end
      else
        error = t("armories.errors.character_idx_not_found", name: name)
      end
    rescue StandardError => e
      error = localized_error_message(e)
    end

    progress_data.each_key do |bucket|
      progress_data[bucket].sort_by! { |entry| -entry[:progress].to_i }
    end

    # Aggregate materials by bucket
    materials_by_bucket = {}

    progress_data.each_key do |bucket|
      entries = progress_data[bucket] || []
      bucket_materials = entries.flat_map { |entry| entry[:materials] || [] }
      grouped_bucket = bucket_materials.group_by { |m| m[:name] }

      materials_by_bucket[bucket] = grouped_bucket.map do |material_name, mats|
        total_needed = mats.sum { |m| m[:needed].to_i }
        collections_count = mats.size

        {
          name: material_name,
          total_needed: total_needed,
          collections_count: collections_count
        }
      end.sort_by { |m| [ -m[:total_needed].to_i, -m[:collections_count].to_i, m[:name].to_s ] }
    end

    # Aggregate materials across all buckets (general view)
    all_materials = progress_data.values.flatten.flat_map { |entry| entry[:materials] || [] }
    grouped = all_materials.group_by { |m| m[:name] }

    top_materials = grouped.map do |material_name, mats|
      total_needed = mats.sum { |m| m[:needed].to_i }
      collections_count = mats.size

      {
        name: material_name,
        total_needed: total_needed,
        collections_count: collections_count
      }
    end.sort_by { |m| [ -m[:total_needed].to_i, -m[:collections_count].to_i, m[:name].to_s ] }

    {
      character_idx: character_idx,
      progress_data: progress_data,
      top_materials: top_materials,
      collection_data: collection_data,
      materials_by_bucket: materials_by_bucket,
      error: error
    }
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
