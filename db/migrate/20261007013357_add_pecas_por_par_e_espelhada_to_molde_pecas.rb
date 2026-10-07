# Etapa 1.2 (3/3, parte 3b, decided 06/10/2026): the Corte page counts pieces,
# not pairs — each part of a molde says how many pieces a pair takes and
# whether they are mirrored (half right, half left).
class AddPecasPorParEEspelhadaToMoldePecas < ActiveRecord::Migration[8.1]
  def change
    add_column :molde_pecas, :pecas_por_par, :integer, default: 2, null: false
    add_column :molde_pecas, :espelhada, :boolean, default: false, null: false
  end
end
