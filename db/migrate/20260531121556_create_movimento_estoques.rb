class CreateMovimentoEstoques < ActiveRecord::Migration[8.1]
  def change
    create_table :movimento_estoques do |t|
      t.references :materia_prima, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.string :tipo, null: false
      t.decimal :quantidade, null: false, default: 0
      t.decimal :valor, precision: 10, scale: 2

      t.timestamps
    end
    add_index :movimento_estoques, :created_at
  end
end
