# Etapa 1.2 (2/3, parte 2): the client approves the arte, not each file
# (decided 02/10/2026). A request or an approval belongs to the arte and keeps
# the "photo" of what was sent/approved: the version in use of each of its
# files at that moment (`arquivo_version_ids`). It stays valid while those
# files keep those versions; a file added later doesn't undo it.
#
# arquivo_id / arquivo_version_id stay: the file whose page it came from (the
# attachment lives under its uuid). Existing records get their arte and a
# photo of their own version — the same state they had.
class AprovacaoPorArte < ActiveRecord::Migration[8.1]
  TABELAS = %i[aprovacoes_arte solicitacoes_aprovacao].freeze

  def up
    TABELAS.each do |tabela|
      add_reference tabela, :arte, foreign_key: true
      add_column tabela, :arquivo_version_ids, :json, null: false, default: []
      execute <<~SQL
        UPDATE #{tabela}
        SET arte_id = (SELECT arquivos.arte_id FROM arquivos WHERE arquivos.id = #{tabela}.arquivo_id),
            arquivo_version_ids = json_array(arquivo_version_id)
      SQL
      change_column_null tabela, :arte_id, false
    end
  end

  def down
    TABELAS.each do |tabela|
      remove_column tabela, :arquivo_version_ids
      remove_reference tabela, :arte, foreign_key: true
    end
  end
end
