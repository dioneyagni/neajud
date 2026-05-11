class CreateStampTimeLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :stamp_time_logs do |t|
      t.string :uuid, null: false
      t.references :stamp, null: false, foreign_key: true
      t.integer :previous_seconds, null: false
      t.integer :new_seconds, null: false
      t.string :changed_by

      t.timestamps
    end

    add_index :stamp_time_logs, :uuid, unique: true
  end
end
