class ArmoryStellarNormalizer
  def self.call(payload)
    new(payload).call
  end

  def initialize(payload)
    @payload = payload.is_a?(Hash) ? payload : {}
  end

  def call
    {
      values: normalize_values(@payload["values"]),
      lines: normalize_lines(@payload["lines"])
    }
  end

  private

  def normalize_values(values)
    Array(values).map(&:to_s).map(&:strip).reject(&:blank?)
  end

  def normalize_lines(lines)
    Array(lines).filter_map do |line|
      next unless line.is_a?(Hash)

      {
        line: line["line"].to_i,
        level: line["level"].to_i,
        set_values: normalize_values(line["setValues"]),
        data: normalize_data(line["data"])
      }
    end
  end

  def normalize_data(data)
    Array(data).filter_map do |entry|
      next unless entry.is_a?(Hash)

      {
        name: entry["name"].to_s,
        image_url: entry["imageUrl"].to_s,
        level: entry["level"].to_i,
        line: entry["line"].to_i,
        force: entry["force"].to_i,
        value: entry["value"].to_i
      }
    end
  end
end
