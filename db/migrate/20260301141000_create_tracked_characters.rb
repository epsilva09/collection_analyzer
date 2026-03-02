class CreateTrackedCharacters < ActiveRecord::Migration[8.0]
  def change
    create_table :tracked_characters do |t|
      t.integer :character_idx, null: false
      t.string :character_name, null: false
      t.string :locale, null: false
      t.boolean :active, null: false, default: true
      t.datetime :last_seen_at, null: false
      t.datetime :last_snapshot_at

      t.timestamps
    end

    add_index :tracked_characters, :character_idx, unique: true
    add_index :tracked_characters, :active
  end
end
