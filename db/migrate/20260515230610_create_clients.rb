class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.text :name, null: false
      t.text :responsible, null: false

      t.timestamps
    end
  end
end
