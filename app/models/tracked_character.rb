class TrackedCharacter < ApplicationRecord
  validates :character_idx, presence: true, uniqueness: true
  validates :character_name, presence: true
  validates :locale, presence: true
  validates :last_seen_at, presence: true

  scope :active, -> { where(active: true) }
end
