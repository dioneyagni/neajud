class CreateImageMetadataAndCutLayers < ActiveRecord::Migration[8.1]
  def change
    create_table :stamp_image_metadata do |t|
      t.references :stamp_version, null: false, foreign_key: true
      t.string :colorspace
      t.string :colorspace_error
      t.string :icc_profile
      t.boolean :has_spots, default: false
      t.integer :width_px
      t.integer :height_px
      t.float :dpi
      t.json :metadata
      t.timestamps
    end
    add_index :stamp_image_metadata, :stamp_version_id, unique: true,
              name: "idx_stamp_image_metadata_on_version"

    create_table :cut_layers do |t|
      t.references :stamp_version, null: false, foreign_key: true
      t.string :layer_name, null: false
      t.string :color, null: false
      t.string :annotation, default: "cut"
      t.integer :position
      t.timestamps
    end
  end
end
