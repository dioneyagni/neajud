# Painel 2/4a2 (decided 06/11/2026): the Corte's time comes from the cutting
# machine — each size's inner lines by layer color (nil = not measured yet,
# `bin/rails cortes:medir_camadas`) and the machine's parameters on the
# Corte's rhythm (nil = the default in RitmoProducao::MAQUINA_PADRAO).
# New columns only: nothing is transformed.
class RitmoDoCorte < ActiveRecord::Migration[8.1]
  def change
    add_column :tamanhos, :linhas_por_cor, :json

    change_table :ritmos_producao, bulk: true do |t|
      t.decimal :velocidade_mm_s, precision: 10, scale: 3
      t.decimal :pinca_s, precision: 10, scale: 3
      t.decimal :preparo_min, precision: 10, scale: 3
      t.decimal :recolhimento_pecas_min, precision: 10, scale: 3
      t.decimal :troca_min, precision: 10, scale: 3
    end
  end
end
