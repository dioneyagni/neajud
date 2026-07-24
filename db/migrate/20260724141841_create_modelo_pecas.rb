class CreateModeloPecas < ActiveRecord::Migration[8.1]
  def change
    create_table :modelo_pecas do |t|
      t.references :modelo, null: false, foreign_key: true
      t.references :peca, null: false, foreign_key: true
      t.boolean :needs_cut, null: false, default: true

      t.timestamps
    end

    add_index :modelo_pecas, %i[modelo_id peca_id], unique: true
  end
end
