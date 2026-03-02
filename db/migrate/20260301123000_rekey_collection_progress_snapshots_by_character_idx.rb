class RekeyCollectionProgressSnapshotsByCharacterIdx < ActiveRecord::Migration[8.0]
  def up
    remove_index :collection_progress_snapshots, name: "index_collection_progress_snapshots_unique_per_day", if_exists: true
    remove_index :collection_progress_snapshots, name: "index_collection_progress_snapshots_history_lookup", if_exists: true

    if column_exists?(:collection_progress_snapshots, :character_name_normalized)
      remove_column :collection_progress_snapshots, :character_name_normalized, :string
    end

    change_column_null :collection_progress_snapshots, :character_idx, false

    add_index :collection_progress_snapshots,
              %i[character_idx locale captured_on],
              unique: true,
              name: "index_collection_progress_snapshots_unique_per_day"

    add_index :collection_progress_snapshots,
              %i[character_idx locale created_at],
              name: "index_collection_progress_snapshots_history_lookup"
  end

  def down
    remove_index :collection_progress_snapshots, name: "index_collection_progress_snapshots_unique_per_day", if_exists: true
    remove_index :collection_progress_snapshots, name: "index_collection_progress_snapshots_history_lookup", if_exists: true

    add_column :collection_progress_snapshots, :character_name_normalized, :string, null: false, default: ""

    execute <<~SQL.squish
      UPDATE collection_progress_snapshots
      SET character_name_normalized = LOWER(TRIM(character_name))
    SQL

    change_column_default :collection_progress_snapshots, :character_name_normalized, from: "", to: nil
    change_column_null :collection_progress_snapshots, :character_idx, true

    add_index :collection_progress_snapshots,
              %i[character_name_normalized locale captured_on],
              unique: true,
              name: "index_collection_progress_snapshots_unique_per_day"

    add_index :collection_progress_snapshots,
              %i[character_name_normalized locale created_at],
              name: "index_collection_progress_snapshots_history_lookup"
  end
end
