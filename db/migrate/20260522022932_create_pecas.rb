class CreatePecas < ActiveRecord::Migration[8.1]
  def change
    create_table :pecas do |t|
      t.string :nome, null: false
      t.timestamps
    end
    add_index :pecas, :nome, unique: true
  end
end
