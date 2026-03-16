class CollectionRewardResolver
  THRESHOLDS_BY_REWARD_COUNT = {
    1 => [ 100 ],
    2 => [ 60, 100 ],
    3 => [ 30, 60, 100 ]
  }.freeze

  def self.resolve(details, context: {})
    new(details, context: context).resolved_details
  end

  def self.reward_thresholds(total_rewards)
    reward_count = total_rewards.to_i
    return [] unless reward_count.positive?

    THRESHOLDS_BY_REWARD_COUNT[reward_count] || begin
      step = 100.0 / reward_count
      (1..reward_count).map { |position| (position * step).round }
    end
  end

  def self.reward_applied?(progress:, reward_index:, total_rewards:, payload_applied: nil)
    thresholds = reward_thresholds(total_rewards)
    threshold = thresholds[reward_index]
    return truthy?(payload_applied) if threshold.nil?

    truthy?(payload_applied) || progress.to_i >= threshold
  end

  def self.truthy?(value)
    value == true ||
      value == 1 ||
      value.to_s == "1" ||
      value.to_s.casecmp("true").zero? ||
      value.to_s.casecmp("yes").zero? ||
      value.to_s.casecmp("y").zero?
  end

  def initialize(details, context: {})
    @details = details || {}
    @context = context || {}
  end

  def resolved_details
    {
      values: resolved_values,
      data: normalized_data
    }
  end

  def normalized_data
    @normalized_data ||= Array(raw_data).filter_map do |tier|
      normalize_tier(tier)
    end
  end

  def resolved_values
    return normalize_values(raw_values) if normalized_data.blank?

    values = aggregate_values_from_rewards(normalized_data)
    resolved = values.presence || normalize_values(raw_values)
    report_values_divergence(raw_values: normalize_values(raw_values), resolved_values: resolved)
    resolved
  end

  private

  def raw_values
    @details[:values] || @details["values"] || []
  end

  def raw_data
    @details[:data] || @details["data"] || []
  end

  def normalize_values(values)
    Array(values).map(&:to_s).map(&:strip).reject(&:blank?)
  end

  def normalize_tier(tier)
    return nil unless tier.is_a?(Hash)

    collections = Array(tier["collections"]).filter_map do |collection|
      normalize_collection(collection)
    end

    tier.deep_dup.merge("collections" => collections)
  end

  def normalize_collection(collection)
    return nil unless collection.is_a?(Hash)

    rewards = Array(collection["rewards"]).select { |reward| reward.is_a?(Hash) }
    progress = collection["progress"].to_i
    thresholds = self.class.reward_thresholds(rewards.size)

    resolved_rewards = rewards.map.with_index do |reward, index|
      resolved_reward = reward.deep_dup
      resolved_reward["applied_from_payload"] = reward["applied"] if reward.key?("applied")
      resolved_reward["threshold"] = thresholds[index] if thresholds[index]
      resolved_reward["applied"] = self.class.reward_applied?(
        progress: progress,
        reward_index: index,
        total_rewards: rewards.size,
        payload_applied: reward["applied"]
      )
      resolved_reward
    end

    collection.deep_dup.merge("rewards" => resolved_rewards)
  end

  def aggregate_values_from_rewards(data)
    ordered_keys = []
    aggregated = {}

    Array(data).each do |tier|
      Array(tier["collections"]).each do |collection|
        reward = highest_applied_reward(collection)
        next unless reward

          merge_reward_value!(aggregated, ordered_keys, reward["description"])
      end
    end

    ordered_keys.filter_map do |key|
      format_aggregated_value(key, aggregated[key])
    end
  end

  def merge_reward_value!(aggregated, ordered_keys, description)
    raw = description.to_s.strip
    return if raw.blank?

    parsed = AttributeParser.parse([ raw ])
    attribute_name, metadata = parsed.first
    attribute_name ||= raw
    metadata ||= { value: nil, unit: nil, raw: raw }

    unless aggregated.key?(attribute_name)
      ordered_keys << attribute_name
      aggregated[attribute_name] = {
        value: 0.0,
        unit: metadata[:unit],
        raw: raw,
        numeric: !metadata[:value].nil?
      }
    end

    return unless metadata[:value]

    aggregated[attribute_name][:value] += metadata[:value].to_f
    aggregated[attribute_name][:unit] ||= metadata[:unit]
    aggregated[attribute_name][:numeric] = true
  end

  def highest_applied_reward(collection)
    Array(collection["rewards"]).reverse.find do |reward|
      reward.is_a?(Hash) && self.class.truthy?(reward["applied"])
    end
  end

  def format_aggregated_value(attribute_name, metadata)
    return nil unless metadata
    return metadata[:raw] unless metadata[:numeric]

    value = metadata[:value].to_f
    suffix = metadata[:unit] == :percent ? "%" : ""

    if metadata[:unit] == :percent
      "#{attribute_name} #{format_number(value)}#{suffix}"
    else
      sign = value.negative? ? "-" : "+"
      "#{attribute_name} #{sign}#{format_number(value.abs)}#{suffix}"
    end
  end

  def format_number(value)
    rounded = value.round(2)
    return rounded.to_i.to_s if rounded == rounded.to_i

    format("%.2f", rounded).sub(/0+\z/, "").sub(/\.$/, "")
  end

  def report_values_divergence(raw_values:, resolved_values:)
    return if raw_values == resolved_values

    payload = {
      source: @context[:source].to_s,
      character_name: @context[:character_name].to_s,
      character_idx: @context[:character_idx].to_i,
      raw_values_count: raw_values.size,
      resolved_values_count: resolved_values.size,
      raw_values: raw_values,
      resolved_values: resolved_values
    }

    ActiveSupport::Notifications.instrument("collection_reward_resolver.values_divergence", payload)
    Rails.logger.warn("collection_reward_resolver.values_divergence #{payload.to_json}")
  end
end