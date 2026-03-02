class CreateCollectionProgressSnapshots < ActiveRecord::Migration[8.0]
  def change
    create_table :collection_progress_snapshots do |t|
      t.string :character_name, null: false
      t.string :character_name_normalized, null: false
      t.string :locale, null: false
      t.date :captured_on, null: false
      t.integer :character_idx
      t.integer :total_collections, null: false, default: 0
      t.integer :completed_collections, null: false, default: 0
      t.integer :near_count, null: false, default: 0
      t.integer :mid_count, null: false, default: 0
      t.integer :low_count, null: false, default: 0
      t.integer :below_one_count, null: false, default: 0
      t.decimal :completion_rate, precision: 6, scale: 2, null: false, default: 0

      t.timestamps
    end

    add_index :collection_progress_snapshots,
              %i[character_name_normalized locale captured_on],
              unique: true,
              name: "index_collection_progress_snapshots_unique_per_day"

    add_index :collection_progress_snapshots,
              %i[character_name_normalized locale created_at],
              name: "index_collection_progress_snapshots_history_lookup"
  end
end
