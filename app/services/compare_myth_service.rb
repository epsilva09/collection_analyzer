class CompareMythService
  SPECIAL_ATTRIBUTES = [
    "Perfuracao",
    "PVE Perfuracao",
    "Danos Criticos",
    "PVE Dano Critico",
    "Aumentou todas as tecnicas Amp.",
    "PVE Todas as Tecnicas Amp",
    "Aumentou todos os ataques",
    "PVE Todos os Ataques"
  ].freeze

  PREFIX_REGEX = /\A\s*(PVE\s+)?Ignorar\s+/i

  LINE_VALUE_REGEX = /([-+]?\d+(?:[.,]\d+)?)\s*%?\s*\z/

  SUMMARY_METRICS = [
    { key: :score, label_key: "score" },
    { key: :total_score, label_key: "total_score" },
    { key: :resurrection, label_key: "resurrection" },
    { key: :point, label_key: "point" }
  ].freeze

  def initialize(client: ArmoryClient.new)
    @client = client
  end

  def call(name_a:, name_b:)
    result = empty_result(name_a, name_b)
    comparison_ready = name_a.present? && name_b.present?
    return { comparison_ready: comparison_ready, result: result } unless comparison_ready

    result[:character_a] = build_character_payload(name_a)
    result[:character_b] = build_character_payload(name_b)

    myth_a = result.dig(:character_a, :myth) || {}
    myth_b = result.dig(:character_b, :myth) || {}

    result[:summary_cards] = build_summary_cards(myth_a, myth_b)
    result[:grade_summary] = build_grade_summary(myth_a, myth_b)
    result[:stigma_summary] = build_stigma_summary(myth_a, myth_b)
    result[:line_summary] = build_line_summary(myth_a, myth_b)
    result[:line_attribute_rows] = build_line_attribute_rows(myth_a, myth_b)
    result[:line_node_rows] = build_line_node_rows(myth_a, myth_b)
    result[:grade_rows] = build_grade_rows(myth_a, myth_b)

    { comparison_ready: true, result: result }
  end

  def empty_result(name_a, name_b)
    {
      name_a: name_a,
      name_b: name_b,
      character_a: {},
      character_b: {},
      summary_cards: [],
      grade_summary: {},
      stigma_summary: {},
      line_summary: {},
      line_attribute_rows: [],
      line_node_rows: [],
      grade_rows: []
    }
  end

  private

  def build_character_payload(name)
    profile = @client.fetch_character(name)
    character_idx = profile[:character_idx].to_i

    myth = character_idx.positive? ? @client.fetch_myth(character_idx) : {}

    {
      profile: profile,
      myth: myth
    }
  end

  def build_summary_cards(myth_a, myth_b)
    SUMMARY_METRICS.map do |metric|
      value_a = myth_a[metric[:key]].to_i
      value_b = myth_b[metric[:key]].to_i

      {
        metric: metric[:key],
        label_key: metric[:label_key],
        value_a: value_a,
        value_b: value_b,
        diff: value_a - value_b,
        winner: winner_for(value_a, value_b)
      }
    end
  end

  def build_grade_summary(myth_a, myth_b)
    point_a = myth_a[:point].to_i
    point_b = myth_b[:point].to_i
    score_per_point_a = score_per_point(myth_a)
    score_per_point_b = score_per_point(myth_b)

    next_grade_a = next_grade_target(myth_a)
    next_grade_b = next_grade_target(myth_b)

    {
      grade_a: myth_a[:grade].to_i,
      grade_b: myth_b[:grade].to_i,
      grade_name_a: myth_a[:grade_name].to_s,
      grade_name_b: myth_b[:grade_name].to_s,
      grade_diff: myth_a[:grade].to_i - myth_b[:grade].to_i,
      level_progress_a: progress_percent(myth_a[:level], myth_a[:max_level]),
      level_progress_b: progress_percent(myth_b[:level], myth_b[:max_level]),
      point_progress_a: progress_percent(point_a, myth_a[:max_point]),
      point_progress_b: progress_percent(point_b, myth_b[:max_point]),
      score_per_point_a: score_per_point_a,
      score_per_point_b: score_per_point_b,
      next_grade_a: next_grade_a,
      next_grade_b: next_grade_b,
      estimated_score_to_next_a: (next_grade_a[:remaining_points].to_f * score_per_point_a).round(2),
      estimated_score_to_next_b: (next_grade_b[:remaining_points].to_f * score_per_point_b).round(2)
    }
  end

  def build_stigma_summary(myth_a, myth_b)
    stigma_a = myth_a[:stigma] || {}
    stigma_b = myth_b[:stigma] || {}

    score_a = stigma_a[:score].to_i
    score_b = stigma_b[:score].to_i

    {
      score_a: score_a,
      score_b: score_b,
      score_diff: score_a - score_b,
      grade_a: stigma_a[:grade].to_i,
      grade_b: stigma_b[:grade].to_i,
      exp_a: stigma_a[:exp].to_i,
      exp_b: stigma_b[:exp].to_i,
      progress_a: progress_percent(score_a, stigma_a[:max_score]),
      progress_b: progress_percent(score_b, stigma_b[:max_score]),
      winner: winner_for(score_a, score_b)
    }
  end

  def build_line_summary(myth_a, myth_b)
    lines_a = flatten_lines(myth_a)
    lines_b = flatten_lines(myth_b)

    score_a = lines_a.sum { |line| line[:score].to_i }
    score_b = lines_b.sum { |line| line[:score].to_i }

    {
      total_nodes_a: lines_a.size,
      total_nodes_b: lines_b.size,
      unlocked_a: lines_a.count { |line| line[:locked] != true },
      unlocked_b: lines_b.count { |line| line[:locked] != true },
      avg_level_a: average_line_level(lines_a),
      avg_level_b: average_line_level(lines_b),
      total_score_a: score_a,
      total_score_b: score_b,
      total_score_diff: score_a - score_b,
      winner: winner_for(score_a, score_b)
    }
  end

  def build_line_attribute_rows(myth_a, myth_b)
    attributes_a = aggregate_line_attributes(flatten_lines(myth_a))
    attributes_b = aggregate_line_attributes(flatten_lines(myth_b))

    keys = (attributes_a.keys + attributes_b.keys).uniq

    keys.map do |attribute|
      value_a = attributes_a[attribute].to_f
      value_b = attributes_b[attribute].to_f
      metadata = annotate_attribute(attribute)

      {
        attribute: attribute,
        parsed_key: metadata[:parsed_key],
        is_special: metadata[:is_special],
        value_a: value_a,
        value_b: value_b,
        diff: (value_a - value_b).round(2),
        winner: winner_for(value_a, value_b)
      }
    end.sort_by do |entry|
      [
        entry[:is_special] ? 0 : 1,
        special_attribute_position(entry[:parsed_key]),
        -entry[:diff].abs,
        entry[:attribute]
      ]
    end
  end

  def build_grade_rows(myth_a, myth_b)
    grades_a = index_grades(myth_a)
    grades_b = index_grades(myth_b)
    keys = (grades_a.keys + grades_b.keys).uniq.sort

    keys.map do |grade_number|
      row_a = grades_a[grade_number] || {}
      row_b = grades_b[grade_number] || {}

      enabled_a = row_a[:enabled] == true
      enabled_b = row_b[:enabled] == true

      {
        grade: grade_number,
        name_a: row_a[:name].to_s,
        name_b: row_b[:name].to_s,
        force_a: row_a[:force].to_s,
        force_b: row_b[:force].to_s,
        enabled_a: enabled_a,
        enabled_b: enabled_b,
        status: grade_status(enabled_a, enabled_b)
      }
    end
  end

  def build_line_node_rows(myth_a, myth_b)
    nodes_a = aggregate_line_nodes(flatten_lines(myth_a))
    nodes_b = aggregate_line_nodes(flatten_lines(myth_b))
    keys = (nodes_a.keys + nodes_b.keys).uniq

    keys.map do |name|
      row_a = nodes_a[name] || {}
      row_b = nodes_b[name] || {}

      score_a = row_a[:score].to_i
      score_b = row_b[:score].to_i

      {
        line_name: name,
        score_a: score_a,
        score_b: score_b,
        score_diff: score_a - score_b,
        avg_level_a: row_a[:avg_level].to_f,
        avg_level_b: row_b[:avg_level].to_f,
        count_a: row_a[:count].to_i,
        count_b: row_b[:count].to_i,
        winner: winner_for(score_a, score_b)
      }
    end.sort_by { |entry| [ -entry[:score_diff].abs, entry[:line_name] ] }
  end

  def index_grades(myth)
    Array(myth[:grades]).each_with_object({}) do |grade, memo|
      number = grade[:grade].to_i
      next if number <= 0

      memo[number] = grade
    end
  end

  def flatten_lines(myth)
    Array(myth[:lines]).flatten.select { |entry| entry.is_a?(Hash) }
  end

  def aggregate_line_attributes(lines)
    lines.each_with_object(Hash.new(0.0)) do |line, memo|
      attribute, value = parse_line_attribute(line[:name])
      next if attribute.blank?

      memo[attribute] += value.to_f
    end
  end

  def aggregate_line_nodes(lines)
    grouped = Array(lines).group_by { |line| line[:name].to_s.strip }

    grouped.each_with_object({}) do |(name, entries), memo|
      next if name.blank?

      levels = entries.map { |entry| entry[:level].to_i }
      memo[name] = {
        score: entries.sum { |entry| entry[:score].to_i },
        avg_level: levels.empty? ? 0.0 : (levels.sum.to_f / levels.size.to_f).round(2),
        count: entries.size
      }
    end
  end

  def parse_line_attribute(raw_name)
    text = raw_name.to_s.strip
    return [ "", 0.0 ] if text.blank?

    match = text.match(LINE_VALUE_REGEX)
    return [ text, 0.0 ] unless match

    number_str = match[1].to_s.tr(",", ".")
    value = number_str.to_f
    attribute = text.sub(LINE_VALUE_REGEX, "").strip

    [ attribute, value ]
  end

  def annotate_attribute(raw)
    original = raw.to_s.strip
    had_ignore_prefix = !!(original =~ PREFIX_REGEX)
    cleaned = had_ignore_prefix ? original.sub(PREFIX_REGEX, "").strip : original

    parsed = AttributeParser.parse([ cleaned ])
    parsed_key = parsed.keys.first.to_s
    parsed_key = cleaned if parsed_key.blank?

    normalized_key = normalize_key(parsed_key)

    {
      parsed_key: parsed_key,
      is_special: !had_ignore_prefix && SPECIAL_ATTRIBUTES.include?(normalized_key)
    }
  rescue StandardError
    {
      parsed_key: cleaned,
      is_special: false
    }
  end

  def special_attribute_position(parsed_key)
    index = SPECIAL_ATTRIBUTES.find_index { |item| item == normalize_key(parsed_key) }
    index || SPECIAL_ATTRIBUTES.length
  end

  def normalize_key(value)
    text = value.to_s.unicode_normalize(:nfkd).encode("ASCII", replace: "", undef: :replace, invalid: :replace)
    text.gsub(/[[:space:]]+/, " ").strip
  end

  def next_grade_target(myth)
    current_point = myth[:point].to_i
    current_grade = myth[:grade].to_i

    grades = Array(myth[:grades])
      .select { |grade| grade[:grade].to_i.positive? }
      .sort_by { |grade| grade[:grade].to_i }

    next_grade = grades.find { |grade| grade[:grade].to_i > current_grade }

    return { remaining_points: 0, name: "", point: current_point } unless next_grade

    {
      remaining_points: [ next_grade[:point].to_i - current_point, 0 ].max,
      name: next_grade[:name].to_s,
      point: next_grade[:point].to_i
    }
  end

  def progress_percent(value, max)
    max_value = max.to_i
    return 0.0 if max_value <= 0

    ((value.to_f / max_value.to_f) * 100.0).round(2)
  end

  def average_line_level(lines)
    entries = Array(lines)
    return 0.0 if entries.empty?

    (entries.sum { |line| line[:level].to_i }.to_f / entries.size).round(2)
  end

  def score_per_point(myth)
    points = myth[:point].to_i
    return 0.0 if points <= 0

    (myth[:score].to_f / points.to_f).round(4)
  end

  def grade_status(enabled_a, enabled_b)
    return :enabled_both if enabled_a && enabled_b
    return :enabled_a_only if enabled_a
    return :enabled_b_only if enabled_b

    :locked_both
  end

  def winner_for(value_a, value_b)
    return :tie if value_a.to_f == value_b.to_f

    value_a.to_f > value_b.to_f ? :a : :b
  end
end
