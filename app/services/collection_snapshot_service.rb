class CollectionSnapshotService
  def initialize(client: ArmoryClient.new, near_completion_threshold: 80)
    @client = client
    @near_completion_threshold = near_completion_threshold
  end

  def call(name)
    character_idx = @client.fetch_character_idx(name)
    collection_data = []
    progress_data = { near: [], mid: [], low: [], below_one: [] }

    if character_idx
      details = @client.fetch_collection_details(character_idx)
      collection_data = details[:data] || []
      progress_data = build_progress_data(collection_data)
    end

    {
      character_idx: character_idx,
      progress_data: progress_data,
      top_materials: aggregate_materials(progress_data.values.flatten),
      collection_data: collection_data,
      materials_by_bucket: aggregate_materials_by_bucket(progress_data)
    }
  end

  private

  def build_progress_data(collection_data)
    progress_data = { near: [], mid: [], low: [], below_one: [] }

    collection_data.each do |tier|
      next unless tier.is_a?(Hash) && tier["collections"].is_a?(Array)

      tier["collections"].each do |collection|
        progress = collection["progress"].to_i
        next unless progress >= 0 && progress < 100

        materials = build_materials(collection)

        entry = {
          tier: tier["name"],
          name: collection["name"],
          progress: progress,
          missing: 100 - progress,
          rewards: build_rewards(collection, progress),
          materials: materials,
          aggregated_materials: aggregate_entry_materials(materials)
        }
        entry[:status] = entry[:rewards].map { |reward| reward[:description] }.join(", ")

        bucket = progress_bucket(progress)
        progress_data[bucket] << entry if bucket
      end
    end

    progress_data.each_key do |bucket|
      progress_data[bucket].sort_by! { |entry| -entry[:progress].to_i }
    end

    progress_data
  end

  def build_rewards(collection, progress)
    rewards_raw = collection["rewards"] || []

    rewards_raw.map.with_index do |reward, index|
      threshold = reward_threshold(rewards_raw.size, index)
      unlocked_by_progress = progress >= threshold
      unlocked_by_applied = reward.key?("applied") && truthy_value?(reward["applied"])

      unlocked = unlocked_by_applied || unlocked_by_progress

      {
        description: reward["description"].to_s,
        unlocked: unlocked
      }
    end
  end

  def reward_threshold(total_rewards, index)
    if total_rewards == 3
      [ 30, 60, 100 ][index] || 100
    elsif total_rewards.positive?
      (((index + 1) * 100.0) / total_rewards).round
    else
      100
    end
  end

  def truthy_value?(value)
    value == true ||
      value == 1 ||
      value.to_s.casecmp("true").zero? ||
      value.to_s.casecmp("yes").zero? ||
      value.to_s.casecmp("y").zero?
  end

  def build_materials(collection)
    materials = []

    if collection["data"].is_a?(Array)
      collection["data"].each do |item|
        needed = item["max"].to_i - item["progress"].to_i
        if needed > 0
          materials << {
            name: item["name"],
            needed: needed,
            mission: nil,
            current: item["progress"].to_i,
            max: item["max"].to_i
          }
        end
      end
    end

    if collection["missions"].is_a?(Array)
      collection["missions"].each do |mission|
        mission_name = mission["name"] || mission["title"]
        (mission["data"] || []).each do |item|
          needed = item["max"].to_i - item["progress"].to_i
          if needed > 0
            materials << {
              name: item["name"],
              needed: needed,
              mission: mission_name,
              current: item["progress"].to_i,
              max: item["max"].to_i
            }
          end
        end
      end
    end

    materials
  end

  def progress_bucket(progress)
    if progress < 1
      :below_one
    elsif progress <= 29
      :low
    elsif progress <= 59
      :mid
    elsif progress >= @near_completion_threshold
      :near
    end
  end

  def aggregate_materials_by_bucket(progress_data)
    progress_data.each_with_object({}) do |(bucket, entries), memo|
      memo[bucket] = aggregate_materials(entries)
    end
  end

  def aggregate_materials(entries)
    all_materials = entries.flat_map { |entry| entry[:materials] || [] }
    grouped = all_materials.group_by { |material| material[:name] }

    grouped.map do |material_name, materials|
      {
        name: material_name,
        total_needed: materials.sum { |material| material[:needed].to_i },
        collections_count: materials.size
      }
    end.sort_by { |material| [ -material[:total_needed].to_i, -material[:collections_count].to_i, material[:name].to_s ] }
  end

  def aggregate_entry_materials(materials)
    grouped = Array(materials).group_by { |material| material[:name] }

    grouped.map do |material_name, grouped_materials|
      {
        name: material_name,
        needed: grouped_materials.sum { |material| material[:needed].to_i }
      }
    end.sort_by { |material| -material[:needed].to_i }
  end
end
