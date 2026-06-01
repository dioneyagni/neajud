class CreateMateriaPrimas < ActiveRecord::Migration[8.1]
  def change
    create_table :materia_primas do |t|
      t.references :grupo_material, null: false, foreign_key: true
      t.references :cor_material, null: false, foreign_key: true
      t.string :largura, null: false
      t.string :gramatura, null: false

      t.timestamps
    end
    add_index :materia_primas, %i[grupo_material_id cor_material_id largura gramatura],
              unique: true, name: "idx_materia_primas_composite"
  end
end
