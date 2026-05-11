class CreateBatchUploads < ActiveRecord::Migration[8.1]
  def change
    create_table :batch_uploads do |t|
      t.string :uuid, null: false
      t.integer :total_files, default: 0
      t.integer :processed_files, default: 0
      t.integer :failed_files, default: 0
      t.string :uploaded_by

      t.timestamps
    end

    add_index :batch_uploads, :uuid, unique: true
  end
end
