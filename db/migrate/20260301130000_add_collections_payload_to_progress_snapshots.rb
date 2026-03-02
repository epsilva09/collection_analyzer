class AddCollectionsPayloadToProgressSnapshots < ActiveRecord::Migration[8.0]
  def change
    add_column :collection_progress_snapshots, :collections_payload, :json, null: false, default: []
  end
end
