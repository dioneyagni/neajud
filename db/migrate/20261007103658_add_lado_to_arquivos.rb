# Etapa 1.2 (3/3, parte 3c, decided 06/10/2026): a mirrored part (molde_pecas.espelhada)
# may have one file per side. nil = no side: serves both (the printer mirrors it)
# until the arte has a file with a side in that size (decided 07/10/2026).
class AddLadoToArquivos < ActiveRecord::Migration[8.1]
  def change
    add_column :arquivos, :lado, :string
  end
end
