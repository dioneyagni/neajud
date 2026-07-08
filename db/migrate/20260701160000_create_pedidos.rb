class CreatePedidos < ActiveRecord::Migration[8.1]
  def change
    create_table :pedidos do |t|
      t.string :uuid, null: false
      t.references :client, null: true, foreign_key: true
      t.string :status, null: false, default: "rascunho"
      t.text :observacoes

      t.timestamps
    end

    add_index :pedidos, :uuid, unique: true
    add_index :pedidos, :status
  end
end
