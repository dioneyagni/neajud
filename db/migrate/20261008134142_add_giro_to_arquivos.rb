# Etapa 2.2 (1/3, decided 08/10/2026): how a corte's pieces may turn in the
# fit that gives its meters per piece — "nenhum" (as drawn), "180" (default:
# the grain allows turning the piece over) or "90" (0°, 90°, 180°, 270°).
class AddGiroToArquivos < ActiveRecord::Migration[8.1]
  def change
    add_column :arquivos, :giro, :string, default: "180", null: false
  end
end
