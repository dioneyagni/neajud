# Etapa 2.3e (decided 20/10/2026): a metragem baixa adjusts the stock by the
# real minus the expected — the movement points at the baixa, so undoing it
# stops the adjustment counting — and a baixa covering several materials keeps
# each one's measure (material uuid => meters).
class AjusteDoEstoquePelasBaixas < ActiveRecord::Migration[8.1]
  def change
    add_reference :movimento_estoques, :baixa_producao, foreign_key: { to_table: :baixas_producao }, null: true
    add_column :baixas_producao, :medidas, :json, default: {}, null: false
  end
end
