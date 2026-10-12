# Etapa 2.8 (4a, decided 12/10/2026): the client answers in the system. He
# approves (AprovacaoArte, canal "sistema") or asks for changes with a note —
# an AlteracaoArte, which photographs the arte like the other two records.
# The default "Cliente final" gets aprovar_arte: for a função para clientes it
# means approving in the system.
class CreateAlteracoesArte < ActiveRecord::Migration[8.1]
  class Funcao < ActiveRecord::Base
    self.table_name = "funcoes"
  end

  NOME = "Cliente final".freeze

  def up
    create_table :alteracoes_arte do |t|
      t.string :uuid, null: false
      t.references :arte, null: false, foreign_key: true
      t.references :arquivo, null: false, foreign_key: true
      t.references :arquivo_version, null: false, foreign_key: true
      t.json :arquivo_version_ids, null: false, default: []
      t.references :user, null: false, foreign_key: true
      t.text :recado, null: false
      t.datetime :cancelada_em
      t.integer :cancelada_por_id
      t.timestamps
    end
    add_index :alteracoes_arte, :uuid, unique: true

    funcao = Funcao.find_by(nome: NOME, para_cliente: true)
    funcao&.update!(acoes: (Array(funcao.acoes) | %w[aprovar_arte]))
  end

  def down
    funcao = Funcao.find_by(nome: NOME, para_cliente: true)
    funcao&.update!(acoes: Array(funcao.acoes) - %w[aprovar_arte])
    drop_table :alteracoes_arte
  end
end
