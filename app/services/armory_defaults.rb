module ArmoryDefaults
  PROGRESS_BUCKETS = %i[near mid low below_one].freeze

  def self.empty_progress_data
    PROGRESS_BUCKETS.index_with { [] }
  end
end
