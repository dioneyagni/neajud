# Dublagem 5b2a (decided 12/11/2026, Q1a): the group says what its materials
# are counted in — meters, or kg for the cola (Q2a: its consumption in g/m²,
# a new attribute the group asks). The Cola group that the network import
# created goes to kg when it has no material yet: none to convert.
class AddUnidadeAoGrupoMaterial < ActiveRecord::Migration[8.1]
  def up
    add_column :grupo_materiais, :unidade, :string, null: false, default: "m"
    add_column :materia_primas, :consumo_g_m2, :decimal, precision: 8, scale: 2
    trocar_indice(%w[grupo_material_id cor_material_id largura gramatura densidade espessura_mm micras consumo_g_m2 fornecedor])
    cola = select_one("SELECT id FROM grupo_materiais WHERE nome = 'Cola'")
    return unless cola
    return if select_value("SELECT COUNT(*) FROM materia_primas WHERE grupo_material_id = #{cola["id"].to_i}").to_i.positive?

    execute "UPDATE grupo_materiais SET unidade = 'kg', atributos = '{\"consumo_g_m2\":true}' WHERE id = #{cola["id"].to_i}"
  end

  def down
    trocar_indice(%w[grupo_material_id cor_material_id largura gramatura densidade espessura_mm micras fornecedor])
    remove_column :materia_primas, :consumo_g_m2
    remove_column :grupo_materiais, :unidade
  end

  private

  # Two colas told apart by their consumption only are two materials.
  def trocar_indice(colunas)
    remove_index :materia_primas, name: "idx_materia_primas_composite"
    add_index :materia_primas, colunas, name: "idx_materia_primas_composite", unique: true, where: "tipo <> 'dublado'"
  end
end
