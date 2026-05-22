class CreateMoldes < ActiveRecord::Migration[8.1]
  def change
    create_table :moldes do |t|
      t.string :nome, null: false
      t.timestamps
    end
    add_index :moldes, :nome, unique: true
  end
end
