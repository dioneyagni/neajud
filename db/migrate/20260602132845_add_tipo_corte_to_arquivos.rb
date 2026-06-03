class AddTipoCorteToArquivos < ActiveRecord::Migration[8.1]
  def change
    unless column_exists?(:arquivos, :tipo_corte)
      add_column :arquivos, :tipo_corte, :string, default: "corte_estampa", null: false
    end
    unless index_exists?(:arquivos, :tipo_corte)
      add_index :arquivos, :tipo_corte
    end
  end
end
