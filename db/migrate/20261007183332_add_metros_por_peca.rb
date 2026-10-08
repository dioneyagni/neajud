# Etapa 2.2 (1/3, decided 07/10/2026): what a baixa expects comes from the files.
# - tamanhos.metros_por_peca: { "<roll width in mm>" => meters of fabric per
#   piece }, from a simple nesting of the size's DXF (bin/encaixe-dxf.js),
#   computed once per width in the background;
# - empresas: the paper's width (the arte's meters per piece) and how far a
#   baixa may fall below / go above the expected before the operator is warned.
class AddMetrosPorPeca < ActiveRecord::Migration[8.1]
  def change
    add_column :tamanhos, :metros_por_peca, :json, default: {}, null: false
    add_column :empresas, :largura_papel_mm, :integer, default: 1600, null: false
    add_column :empresas, :tolerancia_abaixo_pct, :integer, default: 10, null: false
    add_column :empresas, :tolerancia_acima_pct, :integer, default: 25, null: false
  end
end
