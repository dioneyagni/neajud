# Etapa 2.5b (decided 12/10/2026): a cor lisa is measured in CIE Lab, per
# version (a new version is a tone adjustment: measured again, its name
# kept). The arte gets its color family at the first measure, named
# "Laranja 1" — numbered per family, so the unique key is kind + family +
# number (familia is "" for every other kind). Its material is optional.
class AddCorMedidaToArquivoVersions < ActiveRecord::Migration[8.1]
  def change
    add_column :arquivo_versions, :lab_l, :float
    add_column :arquivo_versions, :lab_a, :float
    add_column :arquivo_versions, :lab_b, :float
    add_column :arquivo_versions, :cor_hex, :string

    add_column :artes, :familia, :string, null: false, default: ""
    add_reference :artes, :materia_prima, foreign_key: true
    remove_index :artes, %i[tipo numero], unique: true
    add_index :artes, %i[tipo familia numero], unique: true
  end
end
