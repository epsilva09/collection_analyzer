class CollectionProgressSnapshot < ApplicationRecord
  validates :character_idx, presence: true
  validates :character_name, presence: true
  validates :locale, presence: true
  validates :captured_on, presence: true
  validates :character_idx, uniqueness: { scope: %i[locale captured_on] }

  before_validation :normalize_fields

  scope :for_character, ->(character_idx, locale) {
    where(character_idx: character_idx.to_i, locale: locale.to_s)
  }

  private

  def normalize_fields
    self.character_name = character_name.to_s.strip
    self.locale = locale.to_s
  end
end
