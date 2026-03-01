module ArmoriesHelper
  def aggregated_materials(materials)
    grouped_materials = Array(materials).group_by { |material| material[:name] }

    grouped_materials.map do |name, grouped|
      {
        name: name,
        needed: grouped.sum { |material| material[:needed].to_i }
      }
    end.sort_by { |material| -material[:needed].to_i }
  end

  def reward_badges(rewards:, status: nil)
    reward_list = Array(rewards)

    if reward_list.any?
      safe_join(
        reward_list.map do |reward|
          badge_class = reward[:unlocked] ? "bg-success" : "bg-dark text-white"
          content_tag(:span, reward[:description], class: "badge #{badge_class} me-1 small")
        end
      )
    elsif status.present?
      fallback = status.to_s.split(",").map(&:strip).reject(&:blank?)
      safe_join(
        fallback.map do |label|
          content_tag(:span, label, class: "badge bg-dark text-white me-1 small")
        end
      )
    else
      ""
    end
  end

  def progress_bucket_label(bucket)
    case bucket&.to_sym
    when :near
      t("armories.progress.labels.near")
    when :mid
      t("armories.progress.labels.mid")
    when :low
      t("armories.progress.labels.low")
    else
      t("armories.progress.labels.below_one")
    end
  end

  def progress_bucket_badge_class(bucket)
    bucket&.to_sym == :near ? "bg-warning text-dark" : "bg-secondary"
  end

  def normalize_reward_attribute(label)
    normalized = label.to_s.squish
    return "" if normalized.blank?

    normalized = normalized.gsub(/[-+−]?\s*\d+(?:[.,]\d+)?\s*%?/u, "").squish
    normalized = normalized.gsub(/[()]/, "").squish

    normalized
  end
end
