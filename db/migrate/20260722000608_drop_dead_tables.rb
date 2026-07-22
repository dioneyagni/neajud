class DropDeadTables < ActiveRecord::Migration[8.1]
  def change
    drop_table :batch_uploads do |t|
      t.string :uuid, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end

    drop_table :arte_cortes do |t|
      t.integer :arte_id, null: false
      t.integer :corte_id, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end
  end
end
