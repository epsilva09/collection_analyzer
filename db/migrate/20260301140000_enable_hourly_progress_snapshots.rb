class EnableHourlyProgressSnapshots < ActiveRecord::Migration[8.0]
  def up
    add_column :collection_progress_snapshots, :captured_at, :datetime

    execute <<~SQL.squish
      UPDATE collection_progress_snapshots
      SET captured_at = COALESCE(created_at, datetime(captured_on))
      WHERE captured_at IS NULL
    SQL

    change_column_null :collection_progress_snapshots, :captured_at, false

    remove_index :collection_progress_snapshots, name: "index_collection_progress_snapshots_unique_per_day", if_exists: true
    add_index :collection_progress_snapshots,
              %i[character_idx locale captured_at],
              name: "index_collection_progress_snapshots_by_time"
  end

  def down
    remove_index :collection_progress_snapshots, name: "index_collection_progress_snapshots_by_time", if_exists: true

    add_index :collection_progress_snapshots,
              %i[character_idx locale captured_on],
              unique: true,
              name: "index_collection_progress_snapshots_unique_per_day"

    remove_column :collection_progress_snapshots, :captured_at
  end
end
