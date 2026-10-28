# Dublagem 1/5 (decided 27/10/2026, docs/plano.md "Dublagem e venda em
# etapas"): the grupo acts as a family — its roles (superfície, base), whether
# it prints (sim, ressalvas with the warning's text, não) and which attributes
# its materials ask for, each required or not. The existing groups keep
# today's behavior: a superfície that prints, asking a required gramatura.
# The material's own attributes join the duplicate rule, or Espuma TC4 3 mm
# and 5 mm of the same color and width would be "the same material".
class MateriaisComoFamilias < ActiveRecord::Migration[8.1]
  CHAVE_ANTIGA = %i[grupo_material_id cor_material_id largura gramatura].freeze
  CHAVE_NOVA = CHAVE_ANTIGA + %i[densidade espessura_mm micras fornecedor]

  def change
    change_table :grupo_materiais, bulk: true do |t|
      t.boolean :superficie, default: true, null: false
      t.boolean :base, default: false, null: false
      t.string :estampavel, default: "sim", null: false
      t.text :ressalva
      t.json :atributos, default: { "gramatura" => true }, null: false
    end

    change_table :materia_primas, bulk: true do |t|
      t.string :densidade
      t.decimal :espessura_mm, precision: 6, scale: 2
      t.integer :micras
      t.string :fornecedor
    end

    remove_index :materia_primas, CHAVE_ANTIGA, unique: true, name: "idx_materia_primas_composite"
    add_index :materia_primas, CHAVE_NOVA, unique: true, name: "idx_materia_primas_composite"
  end
end
