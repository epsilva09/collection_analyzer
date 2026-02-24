class AttributeParser
  # Parse an array of strings like:
  # "HP +1250", "Danos Críticos 50%", "PVE Defesa +140"
  # Returns a hash: { "HP" => { value: 1250.0, unit: :number, raw: "HP +1250" }, ... }
  NUMBER_RE = /([+\-−]?\d+(?:\.\d+)?%?)\s*$/

  def self.parse(values)
    return {} unless values.is_a?(Array)

    values.each_with_object({}) do |raw, memo|
      next unless raw && raw.is_a?(String)
      s = raw.strip
      m = s.match(NUMBER_RE)
      if m
        num_token = m[1]
        name = s[0...m.begin(0)].strip
        # fallback if name empty (rare)
        name = s if name.empty?

        unit = num_token.end_with?('%') ? :percent : :number
        # normalize number: remove percent or plus signs and replace unicode minus
        cleaned = num_token.tr('＋', '+').tr('−', '-')
        cleaned = cleaned.delete('+')
        cleaned = cleaned.delete_suffix('%')
        value = cleaned.include?('.') ? cleaned.to_f : cleaned.to_f

        memo[name] = { value: value, unit: unit, raw: raw }
      else
        # if we can't parse a number, keep raw with nil value
        memo[s] = { value: nil, unit: nil, raw: raw }
      end
    end
  end
end
