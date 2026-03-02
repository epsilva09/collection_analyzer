class RenameChangedColumnOnProgressSnapshots < ActiveRecord::Migration[8.0]
  def up
    if column_exists?(:collection_progress_snapshots, :changed)
      remove_index :collection_progress_snapshots, name: "index_collection_progress_snapshots_changed_timeline", if_exists: true
      rename_column :collection_progress_snapshots, :changed, :has_changes
      add_index :collection_progress_snapshots,
                %i[character_idx locale has_changes captured_at],
                name: "index_collection_progress_snapshots_changed_timeline"
    end
  end

  def down
    if column_exists?(:collection_progress_snapshots, :has_changes)
      remove_index :collection_progress_snapshots, name: "index_collection_progress_snapshots_changed_timeline", if_exists: true
      rename_column :collection_progress_snapshots, :has_changes, :changed
      add_index :collection_progress_snapshots,
                %i[character_idx locale changed captured_at],
                name: "index_collection_progress_snapshots_changed_timeline"
    end
  end
end
