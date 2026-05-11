class CreateStamps < ActiveRecord::Migration[8.1]
  def change
    create_table :stamps do |t|
      t.string :uuid, null: false
      t.string :original_file
      t.string :preview_file
      t.string :overlay_file
      t.string :filename, null: false
      t.string :extension, null: false
      t.string :mime_type, null: false
      t.string :colorspace
      t.boolean :has_spots, default: false
      t.integer :estimated_seconds, default: 0
      t.integer :annotated_seconds
      t.string :status, null: false, default: "pending"
      t.string :batch_id

      t.timestamps
    end

    add_index :stamps, :uuid, unique: true
    add_index :stamps, :status
  end
end
