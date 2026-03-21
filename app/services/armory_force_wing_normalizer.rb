class ArmoryForceWingNormalizer
  def self.call(payload)
    new(payload).call
  end

  def initialize(payload)
    @payload = payload.is_a?(Hash) ? payload : {}
  end

  def call
    {
      grade: @payload["grade"].to_i,
      level: @payload["level"].to_i,
      grade_name: @payload["gradeName"].to_s,
      grade_data: normalize_grade_data(@payload["gradeData"]),
      status: normalize_string_array(@payload["status"]),
      buff_value: normalize_string_array(@payload["buffValue"])
    }
  end

  private

  def normalize_string_array(values)
    Array(values).map(&:to_s).map(&:strip).reject(&:blank?)
  end

  def normalize_grade_data(items)
    Array(items).filter_map do |entry|
      next unless entry.is_a?(Hash)

      {
        name: entry["name"].to_s,
        grade: entry["grade"].to_i,
        grade_name: entry["gradeName"].to_s,
        forces: normalize_string_array(entry["forces"]&.map { |item| item.is_a?(Hash) ? item["name"] : item })
      }
    end
  end
end
