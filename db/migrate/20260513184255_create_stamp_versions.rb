class CreateStampVersions < ActiveRecord::Migration[8.1]
  def change
    create_table :stamp_versions do |t|
      t.references :stamp, null: false, foreign_key: true
      t.integer :version_number, null: false
      t.string :uuid, null: false
      t.string :filename, null: false
      t.string :extension, null: false
      t.string :mime_type, null: false
      t.string :original_file, null: false
      t.string :preview_file
      t.string :status, default: "pending", null: false
      t.boolean :approved, default: false, null: false
      t.string :colorspace
      t.boolean :has_spots, default: false
      t.string :icc_profile
      t.integer :width_px
      t.integer :height_px
      t.integer :dpi
      t.string :category
      t.text :category_notes
      t.string :colorspace_error
      t.json :metadata
      t.timestamps
    end

    add_index :stamp_versions, [ :stamp_id, :version_number ], unique: true
    add_index :stamp_versions, :uuid, unique: true
    add_reference :stamps, :approved_version, foreign_key: { to_table: :stamp_versions }
  end
end
