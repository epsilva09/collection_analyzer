class CompareOverviewService
  CARD_METRICS = [
    { key: :level, label_key: "level" },
    { key: :attack_power_pve, label_key: "attack_power_pve" },
    { key: :defense_power_pve, label_key: "defense_power_pve" },
    { key: :attack_power_pvp, label_key: "attack_power_pvp" },
    { key: :defense_power_pvp, label_key: "defense_power_pvp" },
    { key: :myth_score, label_key: "myth_score" },
    { key: :achievement_point, label_key: "achievement_point" }
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

    result[:comparison_cards] = build_comparison_cards(result[:character_a], result[:character_b])
    result[:collection_macro] = build_collection_macro(result[:character_a], result[:character_b])
    result[:progression_gaps] = build_progression_gaps(result[:character_a], result[:character_b])

    { comparison_ready: true, result: result }
  end

  def empty_result(name_a, name_b)
    {
      name_a: name_a,
      name_b: name_b,
      character_a: {},
      character_b: {},
      comparison_cards: [],
      collection_macro: {},
      progression_gaps: []
    }
  end

  private

  def build_character_payload(name)
    profile = @client.fetch_character(name)
    character_idx = profile[:character_idx].to_i

    return { profile: profile, myth: {}, force_wing: {}, honor_medal: {}, stellar: {} } if character_idx <= 0

    {
      profile: profile,
      myth: @client.fetch_myth(character_idx),
      force_wing: @client.fetch_force_wing(character_idx),
      honor_medal: @client.fetch_honor_medal(character_idx),
      stellar: @client.fetch_stellar(character_idx),
      collection: collection_summary(character_idx)
    }
  end

  def collection_summary(character_idx)
    details = CollectionRewardResolver.resolve(
      @client.fetch_collection_details(character_idx),
      context: {
        source: "compare_overview_service",
        character_idx: character_idx
      }
    )

    collections = extract_collections(details[:data])
    total = collections.size
    completed = collections.count { |entry| entry[:progress] >= 100 }
    not_started = collections.count { |entry| entry[:progress] <= 0 }
    in_progress = [ total - completed - not_started, 0 ].max
    near_completion = collections.count { |entry| entry[:progress] >= 80 && entry[:progress] < 100 }
    average_progress = if total.positive?
      (collections.sum { |entry| entry[:progress] }.to_f / total.to_f).round(2)
    else
      0.0
    end

    unlocked_reward_tiers = collections.sum { |entry| entry[:unlocked_rewards].to_i }
    reward_tiers_total = collections.sum { |entry| entry[:total_rewards].to_i }

    {
      total: total,
      completed: completed,
      in_progress: in_progress,
      not_started: not_started,
      near_completion: near_completion,
      average_progress: average_progress,
      unlocked_reward_tiers: unlocked_reward_tiers,
      reward_tiers_total: reward_tiers_total,
      top_targets: collections
        .select { |entry| entry[:progress] < 100 }
        .sort_by { |entry| [ -entry[:progress], entry[:collection_name] ] }
        .first(3)
    }
  end

  def extract_collections(data)
    Array(data).each_with_object([]) do |tier, rows|
      next unless tier.is_a?(Hash)

      tier_name = tier["name"].to_s
      Array(tier["collections"]).each do |collection|
        next unless collection.is_a?(Hash)

        rewards = Array(collection["rewards"])
        rows << {
          tier: tier_name,
          collection_name: collection["name"].to_s,
          progress: collection["progress"].to_i,
          unlocked_rewards: rewards.count { |reward| reward.is_a?(Hash) && CollectionRewardResolver.truthy?(reward["applied"]) },
          total_rewards: rewards.size
        }
      end
    end
  end

  def build_collection_macro(character_a, character_b)
    collection_a = character_a[:collection] || {}
    collection_b = character_b[:collection] || {}

    {
      a: collection_a,
      b: collection_b,
      completed_diff: collection_a[:completed].to_i - collection_b[:completed].to_i,
      average_progress_diff: (collection_a[:average_progress].to_f - collection_b[:average_progress].to_f).round(2),
      near_completion_diff: collection_a[:near_completion].to_i - collection_b[:near_completion].to_i,
      unlocked_reward_diff: collection_a[:unlocked_reward_tiers].to_i - collection_b[:unlocked_reward_tiers].to_i
    }
  end

  def build_comparison_cards(character_a, character_b)
    profile_a = character_a[:profile] || {}
    profile_b = character_b[:profile] || {}

    CARD_METRICS.map do |metric|
      value_a = profile_a[metric[:key]].to_i
      value_b = profile_b[metric[:key]].to_i

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

  def build_progression_gaps(character_a, character_b)
    [
      myth_gap(character_a[:myth] || {}, character_b[:myth] || {}),
      force_wing_gap(character_a[:force_wing] || {}, character_b[:force_wing] || {}),
      honor_medal_gap(character_a[:honor_medal] || {}, character_b[:honor_medal] || {}),
      stellar_gap(character_a[:stellar] || {}, character_b[:stellar] || {})
    ]
  end

  def myth_gap(myth_a, myth_b)
    value_a = progress_percent(myth_a[:level], myth_a[:max_level])
    value_b = progress_percent(myth_b[:level], myth_b[:max_level])

    {
      system: :myth,
      label_key: "myth",
      value_a: value_a,
      value_b: value_b,
      diff: (value_a - value_b).round(2),
      detail_a: "#{myth_a[:grade_name]} (#{myth_a[:level]}/#{myth_a[:max_level]})",
      detail_b: "#{myth_b[:grade_name]} (#{myth_b[:level]}/#{myth_b[:max_level]})",
      winner: winner_for(value_a, value_b)
    }
  end

  def force_wing_gap(wing_a, wing_b)
    value_a = wing_a[:level].to_i
    value_b = wing_b[:level].to_i

    {
      system: :force_wing,
      label_key: "force_wing",
      value_a: value_a,
      value_b: value_b,
      diff: value_a - value_b,
      detail_a: wing_a[:grade_name].to_s,
      detail_b: wing_b[:grade_name].to_s,
      winner: winner_for(value_a, value_b)
    }
  end

  def honor_medal_gap(medal_a, medal_b)
    value_a = medal_a[:percent].to_i
    value_b = medal_b[:percent].to_i

    {
      system: :honor_medal,
      label_key: "honor_medal",
      value_a: value_a,
      value_b: value_b,
      diff: value_a - value_b,
      detail_a: medal_a[:current_grade_name].to_s,
      detail_b: medal_b[:current_grade_name].to_s,
      winner: winner_for(value_a, value_b)
    }
  end

  def stellar_gap(stellar_a, stellar_b)
    value_a = average_line_level(stellar_a)
    value_b = average_line_level(stellar_b)

    {
      system: :stellar,
      label_key: "stellar",
      value_a: value_a,
      value_b: value_b,
      diff: (value_a - value_b).round(2),
      detail_a: "#{Array(stellar_a[:values]).size} valores",
      detail_b: "#{Array(stellar_b[:values]).size} valores",
      winner: winner_for(value_a, value_b)
    }
  end

  def progress_percent(level, max_level)
    max = max_level.to_i
    return 0.0 if max <= 0

    ((level.to_f / max.to_f) * 100.0).round(2)
  end

  def average_line_level(stellar)
    lines = Array(stellar[:lines])
    return 0.0 if lines.empty?

    (lines.sum { |line| line[:level].to_i }.to_f / lines.size).round(2)
  end

  def winner_for(value_a, value_b)
    return :tie if value_a.to_f == value_b.to_f

    value_a.to_f > value_b.to_f ? :a : :b
  end
end
