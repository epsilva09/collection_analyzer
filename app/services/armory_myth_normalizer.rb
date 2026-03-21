class ArmoryMythNormalizer
  def self.call(payload)
    new(payload).call
  end

  def initialize(payload)
    @payload = payload.is_a?(Hash) ? payload : {}
  end

  def call
    total_point = extract_total_point

    {
      level: to_i(@payload["level"]),
      max_level: to_i(@payload["maxLevel"]),
      grade: to_i(@payload["grade"]),
      grade_name: @payload["gradeName"].to_s,
      point: to_i(@payload["point"]),
      total_point: total_point,
      max_point: to_i(@payload["maxPoint"]),
      score: to_i(@payload["score"]),
      total_score: to_i(@payload["totalScore"]),
      resurrection: to_i(@payload["resurrection"]),
      stigma: normalize_stigma(@payload["stigma"]),
      grades: normalize_grades(@payload["grades"]),
      lines: normalize_lines(@payload["lines"]),
      values: normalize_values(@payload["values"])
    }
  end

  private

  def to_i(value)
    return value if value.is_a?(Integer)
    return value.to_i if value.is_a?(Float)

    raw = value.to_s.strip
    return 0 if raw.blank?

    # API may return numbers formatted with separators (e.g. 26,500 / 26.500).
    # Keep sign and digits only to preserve integer magnitude.
      normalized = raw.gsub(/[^\d-]/, "")
    return 0 if normalized.blank? || normalized == "-"

    normalized.to_i
  end

  def normalize_values(values)
    Array(values).map(&:to_s).map(&:strip).reject(&:blank?)
  end

  def extract_total_point
    total = to_i(@payload["totalPoint"])
    total = to_i(@payload["totalPoints"]) if total <= 0
    total = to_i(@payload["point"]) if total <= 0
    total
  end

  def normalize_stigma(stigma)
    data = stigma.is_a?(Hash) ? stigma : {}
    {
      grade: to_i(data["grade"]),
      score: to_i(data["score"]),
      max_score: to_i(data["maxScore"]),
      exp: to_i(data["exp"])
    }
  end

  def normalize_grades(grades)
    Array(grades).filter_map do |grade|
      next unless grade.is_a?(Hash)

      {
        grade: to_i(grade["grade"]),
        point: to_i(grade["point"]),
        name: grade["name"].to_s,
        force: grade["force"].to_s,
        enabled: !!grade["enabled"]
      }
    end
  end

  def normalize_lines(lines)
    Array(lines).map do |line|
      Array(line).filter_map do |node|
        next unless node.is_a?(Hash)

        {
          id: to_i(node["id"]),
          level: to_i(node["level"]),
          max_level: to_i(node["maxLevel"]),
          score: to_i(node["score"]),
          name: node["name"].to_s,
          image_url: node["imageUrl"].to_s,
          grade_color: node["gradeColor"].to_s,
          locked: !!node["locked"]
        }
      end
    end
  end
end
