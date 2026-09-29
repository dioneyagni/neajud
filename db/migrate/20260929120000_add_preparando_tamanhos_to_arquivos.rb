# Etapa 0.6 (2/3 + 3/3): preparing a corte's tamanhos — re-detecting them
# when organizing failed, extracting each size's DXF and its preview — moved
# out of organize/configure_layers into PreparacaoTamanhosJob. While it runs
# the corte page shows "Preparando os tamanhos…"; this marks it.
class AddPreparandoTamanhosToArquivos < ActiveRecord::Migration[8.1]
  def change
    add_column :arquivos, :preparando_tamanhos_desde, :datetime
  end
end
