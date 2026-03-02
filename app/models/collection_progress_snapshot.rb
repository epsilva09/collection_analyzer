class CollectionProgressSnapshot < ApplicationRecord
  validates :character_idx, presence: true
  validates :character_name, presence: true
  validates :locale, presence: true
  validates :captured_on, presence: true
  validates :captured_at, presence: true

  before_validation :normalize_fields

  scope :for_character, ->(character_idx, locale) {
    where(character_idx: character_idx.to_i, locale: locale.to_s)
  }

  scope :for_day, ->(day) {
    where(captured_on: day)
  }

  scope :for_hour, ->(hour) {
    where("CAST(strftime('%H', captured_at) AS INTEGER) = ?", hour.to_i)
  }

  private

  def normalize_fields
    self.character_name = character_name.to_s.strip
    self.locale = locale.to_s
    self.captured_on ||= captured_at&.to_date
    self.captured_at ||= captured_on&.in_time_zone
  end
end
