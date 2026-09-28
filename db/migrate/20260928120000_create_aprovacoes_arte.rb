# Etapa 0.5 (4/4): the formal record of a client's approval of an arte
# (docs/plano.md, "Aprovação de arte"). One row per approval of one version;
# it never blocks production. Registered by the team with the channel the
# client used and an optional attachment (a WhatsApp print, an email PDF).
# Cancelled by mistake → cancelada_em, never deleted.
#
# Also adds the special action "aprovar_arte" to the default funções that the
# plan's table allows (Admin, Atendimento, Designer); Dono has everything.
class CreateAprovacoesArte < ActiveRecord::Migration[8.1]
  FUNCOES_QUE_APROVAM = %w[Admin Atendimento Designer].freeze

  def up
    create_table :aprovacoes_arte do |t|
      t.string :uuid, null: false
      t.references :arquivo, null: false, foreign_key: true
      t.references :arquivo_version, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :canal, null: false
      t.string :canal_detalhe
      t.text :observacao
      t.date :aprovado_em, null: false
      t.string :anexo_arquivo
      t.string :anexo_nome
      t.string :anexo_tipo
      t.datetime :cancelada_em
      t.integer :cancelada_por_id
      t.timestamps
    end
    add_index :aprovacoes_arte, :uuid, unique: true

    alterar_acao_das_funcoes { |acoes| (acoes + %w[aprovar_arte]).uniq }
  end

  def down
    alterar_acao_das_funcoes { |acoes| acoes - %w[aprovar_arte] }
    drop_table :aprovacoes_arte
  end

  private

  def alterar_acao_das_funcoes
    select_rows("SELECT id, acoes FROM funcoes WHERE nome IN (#{FUNCOES_QUE_APROVAM.map { |n| connection.quote(n) }.join(", ")})").each do |id, acoes|
      novas = yield(JSON.parse(acoes))
      execute "UPDATE funcoes SET acoes = #{connection.quote(novas.to_json)} WHERE id = #{id.to_i}"
    end
  end
end
