class CreateItensPedidoGrade < ActiveRecord::Migration[8.1]
  def change
    create_table :itens_pedido_grade do |t|
      t.references :item_pedido, null: false, foreign_key: { to_table: :itens_pedido }
      t.string :tamanho_nome, null: false
      t.integer :quantidade, null: false, default: 0

      t.timestamps
    end

    add_index :itens_pedido_grade, %i[item_pedido_id tamanho_nome], unique: true, name: "idx_grade_on_item_and_tamanho"
  end
end
