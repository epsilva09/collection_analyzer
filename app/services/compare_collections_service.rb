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
end
