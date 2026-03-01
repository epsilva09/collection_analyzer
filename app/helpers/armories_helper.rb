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

  def progress_filter_options(progress_data)
    entries = progress_data.to_h.values.flatten

    status_options = entries.flat_map do |entry|
      progress_status_filter_values(entry)
    end.uniq.sort_by(&:downcase)

    item_options = entries.flat_map do |entry|
      progress_material_filter_values(entry)
    end.uniq.sort_by(&:downcase)

    {
      status: status_options,
      items: item_options
    }
  end

  def progress_status_filter_values(entry)
    reward_descriptions = Array(entry[:rewards]).map { |reward| reward[:description].to_s.strip }.reject(&:blank?)
    reward_descriptions = entry[:status].to_s.split(",").map(&:strip).reject(&:blank?) if reward_descriptions.blank?

    reward_descriptions.map { |label| normalize_reward_attribute(label) }.reject(&:blank?)
  end

  def progress_material_filter_values(entry)
    aggregated_materials(entry[:materials]).map { |material| material[:name].to_s.strip }.reject(&:blank?)
  end

  def compare_section_groups(annotated_values)
    values = Array(annotated_values)

    {
      special: values.select { |value| value[:is_special] },
      regular: values.reject { |value| value[:is_special] }
    }
  end

  def compare_row_presentation(row, name_a:, name_b:)
    diff_val = row[:diff].to_f

    winner_data =
      if diff_val.positive?
        {
          winner: name_a,
          winner_bg: "winner-a",
          winner_text: "text-white",
          winner_icon: "fas fa-trophy text-warning"
        }
      elsif diff_val.negative?
        {
          winner: name_b,
          winner_bg: "winner-b",
          winner_text: "text-white",
          winner_icon: "fas fa-trophy text-warning"
        }
      else
        {
          winner: t("armories.compare.tie"),
          winner_bg: "winner-tie",
          winner_text: "text-light",
          winner_icon: "fas fa-equals text-light"
        }
      end

    winner_data.merge(
      diff_class: diff_val >= 0 ? "text-success" : "text-danger",
      diff_text: (diff_val >= 0 ? "+" : "") + diff_val.to_s,
      unit_suffix: row[:unit] == :percent ? "%" : ""
    )
  end

  def materials_section_label(section)
    case section&.to_sym
    when :near
      t("armories.progress.labels.near")
    when :mid
      t("armories.progress.labels.mid")
    when :low
      t("armories.progress.labels.low")
    when :below_one
      t("armories.progress.labels.below_one")
    else
      t("armories.materials.labels.general")
    end
  end

  def materials_sections(materials_by_bucket, top_materials)
    ordered_sections = %i[near mid low below_one general]

    ordered_sections.filter_map do |section|
      items = section == :general ? Array(top_materials) : Array(materials_by_bucket.to_h[section])
      next if items.blank?

      {
        key: section,
        label: materials_section_label(section),
        items: items
      }
    end
  end
end
