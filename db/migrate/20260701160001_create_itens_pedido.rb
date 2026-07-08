class CreateItensPedido < ActiveRecord::Migration[8.1]
  def change
    create_table :itens_pedido do |t|
      t.string :uuid, null: false
      t.references :pedido, null: false, foreign_key: true
      t.references :arquivo, null: false, foreign_key: true
      t.references :materia_prima, null: true, foreign_key: true

      t.timestamps
    end

    add_index :itens_pedido, :uuid, unique: true
  end
end
