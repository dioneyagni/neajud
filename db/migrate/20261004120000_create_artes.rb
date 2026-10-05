# Etapa 1.2 (2/3, parte 1): an arte is one envelope of files — one per
# part × size (decided 02/10/2026: "uma arte por molde + referência + nome").
# Each file stays an `arquivos` row (versions, processing, previews and the
# automatic size search keep working per file); `arte_id` says which files
# make the same arte. `tamanho_rotulo` is the size read from the file name
# ("…-29_30" → "29-30", "…-P" → "P"), tried before the dimensions when the
# automatic search looks for the file's tamanho.
#
# Every existing arte file gets an arte of its own (development samples; the
# beta starts empty). Rollback drops the envelope — no file is touched.
class CreateArtes < ActiveRecord::Migration[8.1]
  class ArteDaMigracao < ActiveRecord::Base
    self.table_name = "artes"
  end

  class ArquivoDaMigracao < ActiveRecord::Base
    self.table_name = "arquivos"
  end

  def up
    create_table :artes do |t|
      t.string :uuid, null: false
      t.timestamps
    end
    add_index :artes, :uuid, unique: true
    add_reference :arquivos, :arte, foreign_key: true
    add_column :arquivos, :tamanho_rotulo, :string
    criar_uma_arte_por_arquivo
  end

  def down
    remove_column :arquivos, :tamanho_rotulo
    remove_reference :arquivos, :arte, foreign_key: true
    drop_table :artes
  end

  private

  # Same reading as NomeDoArquivo at the time of writing (kept here so a later
  # change there doesn't change what this migration did).
  def criar_uma_arte_por_arquivo
    ArquivoDaMigracao.reset_column_information
    ArquivoDaMigracao.where.not(category: "corte").or(ArquivoDaMigracao.where(category: nil)).find_each do |arquivo|
      arte = ArteDaMigracao.create!(uuid: SecureRandom.uuid)
      arquivo.update_columns(arte_id: arte.id, tamanho_rotulo: rotulo_do_nome(arquivo.filename))
    end
  end

  def rotulo_do_nome(nome)
    pedacos = File.basename(nome.to_s, ".*").split(/[-_]/).map(&:squish).reject(&:empty?)
    pedacos.shift if pedacos.first&.match?(/\A\d+\z/)
    numeros = pedacos.grep(/\A\d+\z/)
    return numeros.join("-") if numeros.any?

    pedacos.map(&:upcase).find { |p| %w[PP P M G GG XG XGG EG].include?(p) }
  end
end
