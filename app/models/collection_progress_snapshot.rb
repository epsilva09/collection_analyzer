class CollectionProgressSnapshot < ApplicationRecord
  validates :character_idx, presence: true
  validates :character_name, presence: true
  validates :locale, presence: true
  validates :captured_on, presence: true
  validates :captured_at, presence: true, if: :supports_captured_at?
  validates :changes_count, numericality: { greater_than_or_equal_to: 0 }

  before_validation :normalize_fields

  scope :for_character, ->(character_idx, locale) {
    where(character_idx: character_idx.to_i, locale: locale.to_s)
  }

  scope :for_day, ->(day) {
    where(captured_on: day)
  }

  scope :changed_only, -> {
    where(has_changes: true)
  }

  scope :for_hour, ->(hour) {
    next all unless column_names.include?("captured_at")

    where("CAST(strftime('%H', captured_at) AS INTEGER) = ?", hour.to_i)
  }

  private

  def normalize_fields
    self.character_name = character_name.to_s.strip
    self.locale = locale.to_s
    if supports_captured_at?
      self.captured_on ||= captured_at&.to_date
      self.captured_at ||= captured_on&.in_time_zone
    end
  end

  def supports_captured_at?
    self.class.column_names.include?("captured_at")
  end
end
