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
    result[:line_id_rows] = build_line_id_rows(myth_a, myth_b)
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
      line_id_rows: [],
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
    point_a = myth_total_points(myth_a)
    point_b = myth_total_points(myth_b)
    total_score_a = myth_total_score(myth_a)
    total_score_b = myth_total_score(myth_b)
    score_per_point_a = score_per_point(myth_a)
    score_per_point_b = score_per_point(myth_b)

    current_grade_a = current_grade_target(myth_a)
    current_grade_b = current_grade_target(myth_b)
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
      current_grade_a: current_grade_a,
      current_grade_b: current_grade_b,
      next_grade_a: next_grade_a,
      next_grade_b: next_grade_b,
      progress_missing_a: missing_percent_in_grade_span(total_score_a, current_grade_a[:point], next_grade_a[:point]),
      progress_missing_b: missing_percent_in_grade_span(total_score_b, current_grade_b[:point], next_grade_b[:point]),
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

  def build_line_id_rows(myth_a, myth_b)
    nodes_a = index_line_nodes_by_id(myth_a)
    nodes_b = index_line_nodes_by_id(myth_b)
    ids = (nodes_a.keys + nodes_b.keys).uniq.sort

    rows = ids.map do |id|
      node_a = nodes_a[id] || {}
      node_b = nodes_b[id] || {}

      points_a = node_a[:score].to_i
      points_b = node_b[:score].to_i
      diff = points_a - points_b
      split_a = split_line_name(node_a[:name])
      split_b = split_line_name(node_b[:name])

      {
        id: id,
        position_a: node_a[:slot_position],
        position_b: node_b[:slot_position],
        points_a: points_a,
        points_b: points_b,
        diff: diff,
        name_a: node_a[:name].to_s,
        name_b: node_b[:name].to_s,
        attribute_a: split_a[:attribute],
        attribute_b: split_b[:attribute],
        value_label_a: split_a[:value_label],
        value_label_b: split_b[:value_label],
        winner: winner_for(points_a, points_b),
        top_for_a: false,
        top_for_b: false
      }
    end

    top_a_diff = rows.select { |row| row[:diff].positive? }.map { |row| row[:diff] }.max
    top_b_diff = rows.select { |row| row[:diff].negative? }.map { |row| row[:diff].abs }.max

    rows.each do |row|
      row[:top_for_a] = top_a_diff.present? && row[:diff] == top_a_diff
      row[:top_for_b] = top_b_diff.present? && row[:diff].abs == top_b_diff && row[:diff].negative?
    end

    rows
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

  def index_line_nodes_by_id(myth)
    flatten_lines_with_position(myth).each_with_object({}) do |node, memo|
      id = node[:id].to_i
      next if id <= 0

      memo[id] = {
        score: node[:score].to_i,
        slot_position: node[:slot_position].to_i,
        name: node[:name].to_s
      }
    end
  end

  def split_line_name(raw_name)
    text = raw_name.to_s.strip
    return { attribute: "", value_label: "" } if text.blank?

    match = text.match(/\A(.+?)\s+([-+]?\d+(?:[.,]\d+)?\s*%?)\s*\z/)
    return { attribute: text, value_label: "" } unless match

    {
      attribute: match[1].to_s.strip,
      value_label: match[2].to_s.strip
    }
  end

  def flatten_lines_with_position(myth)
    Array(myth[:lines]).each_with_index.flat_map do |slot, slot_index|
      Array(slot).filter_map do |node|
        next unless node.is_a?(Hash)

        node.merge(slot_position: slot_index + 1)
      end
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
    current_total_score = myth_total_score(myth)

    grades = Array(myth[:grades]).select { |grade| grade[:grade].to_i.positive? }
    next_grade = grades.find { |grade| grade[:enabled] != true }

    return { remaining_points: 0, name: "", point: current_total_score } unless next_grade

    next_point_required = next_grade[:point].to_i
    points_gap = next_point_required - current_total_score

    {
      remaining_points: [ points_gap, 0 ].max,
      name: next_grade[:name].to_s,
      point: next_point_required
    }
  end

  def current_grade_target(myth)
    grades = Array(myth[:grades]).select { |grade| grade[:grade].to_i.positive? }
    current_grade = grades.select { |grade| grade[:enabled] == true }.max_by { |grade| grade[:grade].to_i }
    current_grade ||= grades.find { |grade| grade[:grade].to_i == myth[:grade].to_i }

    return { point: 0, name: "", grade: myth[:grade].to_i } unless current_grade

    {
      point: current_grade[:point].to_i,
      name: current_grade[:name].to_s,
      grade: current_grade[:grade].to_i
    }
  end

  def missing_percent_in_grade_span(current_total_score, current_grade_point, next_grade_point)
    span = next_grade_point.to_i - current_grade_point.to_i
    return 0.0 if span <= 0

    remaining = [ next_grade_point.to_i - current_total_score.to_i, 0 ].max
    ((remaining.to_f / span.to_f) * 100.0).round(2)
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
    points = myth_total_points(myth)
    return 0.0 if points <= 0

    (myth[:score].to_f / points.to_f).round(4)
  end

  def myth_total_points(myth)
    total_point = myth[:total_point].to_i
    return total_point if total_point.positive?

    myth[:point].to_i
  end

  def myth_total_score(myth)
    total_score = myth[:total_score].to_i
    return total_score if total_score.positive?

    myth_total_points(myth)
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
