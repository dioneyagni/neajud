class FixMateriaPrimasForeignKeys < ActiveRecord::Migration[8.1]
  def up
    create_table :materia_primas_v2 do |t|
      t.references :grupo_material, null: false, foreign_key: { to_table: :grupo_materiais }
      t.references :cor_material, null: false, foreign_key: { to_table: :cor_materiais }
      t.string :largura, null: false
      t.string :gramatura, null: false
      t.timestamps
    end

    execute <<-SQL
      INSERT INTO materia_primas_v2
        (id, grupo_material_id, cor_material_id, largura, gramatura, created_at, updated_at)
      SELECT id, grupo_material_id, cor_material_id, largura, gramatura, created_at, updated_at
        FROM materia_primas
    SQL

    drop_table :materia_primas
    rename_table :materia_primas_v2, :materia_primas

    add_index :materia_primas, %i[grupo_material_id cor_material_id largura gramatura],
              unique: true, name: "idx_materia_primas_composite"
  end

  def down
    execute "PRAGMA foreign_keys = OFF"

    create_table :materia_primas_v2 do |t|
      t.references :grupo_material, null: false, foreign_key: { to_table: :grupo_materials }
      t.references :cor_material, null: false, foreign_key: { to_table: :cor_materials }
      t.string :largura, null: false
      t.string :gramatura, null: false
      t.timestamps
    end

    execute <<-SQL
      INSERT INTO materia_primas_v2
        (id, grupo_material_id, cor_material_id, largura, gramatura, created_at, updated_at)
      SELECT id, grupo_material_id, cor_material_id, largura, gramatura, created_at, updated_at
        FROM materia_primas
    SQL

    drop_table :materia_primas
    rename_table :materia_primas_v2, :materia_primas

    add_index :materia_primas, %i[grupo_material_id cor_material_id largura gramatura],
              unique: true, name: "idx_materia_primas_composite"
  ensure
    execute "PRAGMA foreign_keys = ON"
  end
end
