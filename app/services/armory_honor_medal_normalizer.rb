class ArmoryHonorMedalNormalizer
  def self.call(payload)
    new(payload).call
  end

  def initialize(payload)
    @payload = payload.is_a?(Hash) ? payload : {}
  end

  def call
    {
      current_grade: @payload["currentGrade"].to_i,
      current_grade_name: @payload["currentGradeName"].to_s,
      level: @payload["level"].to_i,
      percent: @payload["percent"].to_i,
      grades: normalize_grades(@payload["grades"]),
      values: normalize_values(@payload["values"])
    }
  end

  private

  def normalize_values(values)
    Array(values).map(&:to_s).map(&:strip).reject(&:blank?)
  end

  def normalize_grades(grades)
    Array(grades).filter_map do |grade|
      next unless grade.is_a?(Hash)

      {
        grade: grade["grade"].to_i,
        name: grade["name"].to_s,
        slots: normalize_slots(grade["slots"])
      }
    end
  end

  def normalize_slots(slots)
    Array(slots).filter_map do |slot|
      next unless slot.is_a?(Hash)

      {
        id: slot["id"].to_i,
        level: slot["level"].to_i,
        max_level: slot["maxLevel"].to_i,
        name: slot["name"].to_s,
        description: slot["description"].to_s,
        image_url: slot["imageUrl"].to_s,
        opened: !!slot["opened"],
        force_id: slot["forceId"].to_i,
        force_value: slot["forceValue"].to_i
      }
    end
  end
end
