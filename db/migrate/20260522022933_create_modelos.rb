class CreateModelos < ActiveRecord::Migration[8.1]
  def change
    create_table :modelos do |t|
      t.string :nome, null: false
      t.references :client, null: false, foreign_key: true
      t.timestamps
    end
    add_index :modelos, [ :nome, :client_id ], unique: true
  end
end
