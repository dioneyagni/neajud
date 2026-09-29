# Etapa 0.6 (1/3): the automatic tamanho search (MoldMatchService, up to 37 s
# measured on dev data) moved out of update_modelo into TamanhoAutoAssignJob.
# While it runs the arte page shows "Procurando tamanho…"; this marks it.
class AddBuscandoTamanhoToArquivos < ActiveRecord::Migration[8.1]
  def change
    add_column :arquivos, :buscando_tamanho_desde, :datetime
  end
end
