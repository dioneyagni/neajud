# Etapa 2.2 (1/3, decided 08/10/2026): how a corte's pieces may turn in the
# fit that gives its meters per piece — "nenhum" (as drawn), "180" (turned
# over) or "90" (0°, 90°, 180°, 270°). No default: it isn't always the same,
# so whoever uploads the corte marks it; until then nothing is computed.
class AddGiroToArquivos < ActiveRecord::Migration[8.1]
  def change
    add_column :arquivos, :giro, :string
  end
end
