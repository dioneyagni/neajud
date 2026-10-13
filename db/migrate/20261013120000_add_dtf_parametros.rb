# Etapa 2.6a (decided 13/10/2026): the DTF film is just a width in Parâmetros
# (no material), with the margin left at each edge, the default space between
# etiquetas and the extra rows a pedido prints by default; an arte may set its
# own space (the team's, on its page). Plain columns, no data to transform.
class AddDtfParametros < ActiveRecord::Migration[8.1]
  def change
    change_table :empresas, bulk: true do |t|
      t.integer :largura_filme_dtf_mm, default: 600, null: false
      t.integer :margem_filme_dtf_mm, default: 15, null: false
      t.decimal :espacamento_dtf_mm, precision: 5, scale: 2, default: "1.5", null: false
      t.integer :fileiras_extras_dtf, default: 0, null: false
    end
    add_column :artes, :espacamento_mm, :decimal, precision: 5, scale: 2
  end
end
