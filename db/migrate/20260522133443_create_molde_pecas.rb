class CreateMoldePecas < ActiveRecord::Migration[8.1]
  def change
    create_table :molde_pecas, id: false do |t|
      t.references :molde, null: false, foreign_key: true
      t.references :peca, null: false, foreign_key: true
    end
    add_index :molde_pecas, [ :molde_id, :peca_id ], unique: true
  end
end
