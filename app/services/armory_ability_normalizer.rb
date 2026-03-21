class ArmoryAbilityNormalizer
  def self.call(payload)
    new(payload).call
  end

  def initialize(payload)
    @payload = payload.is_a?(Hash) ? payload : {}
  end

  def call
    {
      passive: normalize_entries(@payload["passive"]),
      blended: normalize_entries(@payload["blended"]),
      karma: normalize_entries(@payload["karma"])
    }
  end

  private

  def normalize_entries(entries)
    Array(entries).filter_map do |entry|
      next unless entry.is_a?(Hash)

      {
        name: entry["name"].to_s,
        level: entry["level"].to_i,
        force: entry["force"].to_s,
        image_url: entry["imageUrl"].to_s,
        target: entry["target"].to_s
      }
    end
  end
end
