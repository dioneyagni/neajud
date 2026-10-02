# Etapa 1.2 (1/3): a corte's grade type — par (29-30), ímpar (30-31), pmg
# (P, M, G…) or furada (irregular ranges: 20-21, 24-25-26, 30) — and, on
# each tamanho, the individual sizes it serves. The tamanho's `nome` stays
# its label (what the arte's full name and the pedido show). Existing cortes
# aren't migrated (development samples): opening their organization proposes
# a deduced type, saved with the organization.
class AddTipoGradeToCortes < ActiveRecord::Migration[8.1]
  def change
    add_column :arquivos, :tipo_grade, :string
    add_column :tamanhos, :numeros, :json, null: false, default: []
  end
end
