class CompareCollectionsService
  SPECIAL_ATTRIBUTES = [
    "Perfuração",
    "PVE Perfuração",
    "Danos Críticos",
    "PVE Dano Crítico",
    "Aumentou todas as técnicas Amp.",
    "PVE Todas as Técnicas Amp",
    "Aumentou todos os ataques",
    "PVE Todos os Ataques"
  ].freeze

  PREFIX_REGEX = /\A\s*(PVE\s+)?Ignorar\s+/i

  def initialize(client: ArmoryClient.new)
    @client = client
  end

  def call(name_a:, name_b:)
    result = empty_result(name_a, name_b)
    comparison_ready = name_a.present? && name_b.present?

    return { comparison_ready: comparison_ready, result: result } unless comparison_ready

    result[:character_idx_a] = @client.fetch_character_idx(name_a)
    result[:character_idx_b] = @client.fetch_character_idx(name_b)

    if result[:character_idx_a]
      details = @client.fetch_collection_details(result[:character_idx_a])
      result[:values_a] = normalize_values(details[:values])
      result[:collection_data_a] = details[:data] || []
    end

    if result[:character_idx_b]
      details = @client.fetch_collection_details(result[:character_idx_b])
      result[:values_b] = normalize_values(details[:values])
      result[:collection_data_b] = details[:data] || []
    end

    parsed_a = AttributeParser.parse(result[:values_a])
    parsed_b = AttributeParser.parse(result[:values_b])

    result[:detailed] = build_detailed_rows(parsed_a, parsed_b)
    result[:detailed_ordered] = order_detailed_rows(result[:detailed])

    result[:common] = (parsed_a.keys & parsed_b.keys).to_a.sort
    result[:only_a] = (parsed_a.keys - parsed_b.keys).to_a.sort
    result[:only_b] = (parsed_b.keys - parsed_a.keys).to_a.sort

    result[:common_annotated] = result[:common].map { |item| annotate_value(item) }
    result[:only_a_annotated] = result[:only_a].map { |item| annotate_value(item) }
    result[:only_b_annotated] = result[:only_b].map { |item| annotate_value(item) }
    result[:collection_comparison] = build_collection_comparison_rows(
      result[:collection_data_a],
      result[:collection_data_b]
    )
    result[:collection_comparison_summary] = summarize_collection_comparison(result[:collection_comparison])

    { comparison_ready: comparison_ready, result: result }
  end

  def empty_result(name_a, name_b)
    {
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
  end

  private

  def normalize_values(values)
    (values || []).map(&:to_s).map(&:strip)
  end

  def build_detailed_rows(parsed_a, parsed_b)
    keys = (parsed_a.keys | parsed_b.keys).to_a.sort

    keys.map do |key|
      value_a = parsed_a[key] || { value: 0.0, unit: nil, raw: nil }
      value_b = parsed_b[key] || { value: 0.0, unit: nil, raw: nil }

      unit = (value_a[:unit] == value_b[:unit]) ? value_a[:unit] || value_b[:unit] : :mixed
      numeric_a = value_a[:value] || 0.0
      numeric_b = value_b[:value] || 0.0

      {
        attribute: key,
        value_a: numeric_a,
        value_b: numeric_b,
        unit: unit,
        diff: (numeric_a - numeric_b),
        raw_a: value_a[:raw],
        raw_b: value_b[:raw]
      }
    end
  end

  def order_detailed_rows(rows)
    annotated = rows.map do |row|
      metadata = annotate_value(row[:attribute])
      row.merge(
        cleaned_attribute: metadata[:cleaned],
        parsed_key: metadata[:parsed_key],
        is_special: metadata[:is_special],
        had_ignore_prefix: metadata[:had_ignore_prefix]
      )
    end

    special_rows = annotated.select { |row| row[:is_special] }
    special_rows.sort_by! do |row|
      index = SPECIAL_ATTRIBUTES.find_index { |special| row[:parsed_key] == special }
      index || SPECIAL_ATTRIBUTES.length
    end

    regular_rows = annotated.reject { |row| row[:is_special] }
    special_rows + regular_rows
  end

  def annotate_value(raw)
    original = raw.to_s.strip
    had_ignore_prefix = !!(original =~ PREFIX_REGEX)
    cleaned = had_ignore_prefix ? original.sub(PREFIX_REGEX, "").strip : original

    parsed = AttributeParser.parse([ cleaned ])
    parsed_key = parsed.keys.first.to_s
    parsed_key = cleaned if parsed_key.blank?

    is_special = !had_ignore_prefix && SPECIAL_ATTRIBUTES.include?(parsed_key)

    {
      raw: raw,
      cleaned: cleaned,
      parsed_key: parsed_key,
      is_special: is_special,
      had_ignore_prefix: had_ignore_prefix
    }
  rescue StandardError
    {
      raw: raw,
      cleaned: cleaned,
      parsed_key: cleaned,
      is_special: false,
      had_ignore_prefix: had_ignore_prefix
    }
  end

  def build_collection_comparison_rows(collection_data_a, collection_data_b)
    indexed_a = index_collection_progress_rows(collection_data_a)
    indexed_b = index_collection_progress_rows(collection_data_b)

    keys = (indexed_a.keys + indexed_b.keys).uniq.sort

    keys.map do |key|
      row_a = indexed_a[key] || {}
      row_b = indexed_b[key] || {}

      progress_a = row_a[:progress]
      progress_b = row_b[:progress]
      bonuses_a = row_a[:bonuses] || []
      bonuses_b = row_b[:bonuses] || []

      unlocked_a = bonuses_a.count { |bonus| bonus[:unlocked] }
      unlocked_b = bonuses_b.count { |bonus| bonus[:unlocked] }

      {
        key: key,
        tier: row_a[:tier] || row_b[:tier],
        collection_name: row_a[:collection_name] || row_b[:collection_name],
        progress_a: progress_a,
        progress_b: progress_b,
        progress_diff: progress_a.to_i - progress_b.to_i,
        done_a: progress_a.to_i >= 100,
        done_b: progress_b.to_i >= 100,
        bonuses_a: bonuses_a,
        bonuses_b: bonuses_b,
        unlocked_bonuses_a: unlocked_a,
        unlocked_bonuses_b: unlocked_b,
        total_bonuses_a: bonuses_a.size,
        total_bonuses_b: bonuses_b.size,
        bonus_diff: unlocked_a - unlocked_b
      }
    end
  end

  def index_collection_progress_rows(collection_data)
    Array(collection_data).each_with_object({}) do |tier, memo|
      next unless tier.is_a?(Hash)

      tier_name = tier["name"].to_s
      collections = tier["collections"]
      next unless collections.is_a?(Array)

      collections.each do |collection|
        next unless collection.is_a?(Hash)

        collection_name = collection["name"].to_s
        key = [ tier_name, collection_name ].join("::")

        memo[key] = {
          tier: tier_name,
          collection_name: collection_name,
          progress: collection["progress"].to_i,
          bonuses: extract_bonus_rows(collection)
        }
      end
    end
  end

  def extract_bonus_rows(collection)
    rewards = Array(collection["rewards"]).select { |reward| reward.is_a?(Hash) }
    progress = collection["progress"].to_i

    rewards.map.with_index do |reward, index|
      description = reward["description"].to_s.strip
      next if description.blank?

      threshold = reward_threshold(rewards.size, index)
      unlocked_by_progress = progress >= threshold
      unlocked_by_applied = reward.key?("applied") && truthy_value?(reward["applied"])

      {
        description: description,
        unlocked: unlocked_by_applied || unlocked_by_progress
      }
    end.compact
  end

  def reward_threshold(total_rewards, index)
    if total_rewards == 3
      [ 30, 60, 100 ][index] || 100
    elsif total_rewards.positive?
      (((index + 1) * 100.0) / total_rewards).round
    else
      100
    end
  end

  def truthy_value?(value)
    value == true ||
      value == 1 ||
      value.to_s == "1" ||
      value.to_s.casecmp("true").zero? ||
      value.to_s.casecmp("yes").zero? ||
      value.to_s.casecmp("y").zero?
  end

  def summarize_collection_comparison(rows)
    rows = Array(rows)

    {
      total: rows.size,
      completed_both: rows.count { |row| row[:done_a] && row[:done_b] },
      completed_only_a: rows.count { |row| row[:done_a] && !row[:done_b] },
      completed_only_b: rows.count { |row| row[:done_b] && !row[:done_a] },
      pending_both: rows.count { |row| !row[:done_a] && !row[:done_b] }
    }
  end
end
