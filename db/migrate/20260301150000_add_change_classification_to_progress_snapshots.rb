class AddChangeClassificationToProgressSnapshots < ActiveRecord::Migration[8.0]
  def change
    add_column :collection_progress_snapshots, :has_changes, :boolean, null: false, default: true
    add_column :collection_progress_snapshots, :changes_count, :integer, null: false, default: 0

    add_index :collection_progress_snapshots,
              %i[character_idx locale has_changes captured_at],
              name: "index_collection_progress_snapshots_changed_timeline"
  end
end
