# Etapa 0.5 (4/4), changed before merge (28/09/2026): an arte only waits for
# approval once someone sends it to the client ("Enviar para aprovação").
# Without a request no badge and no "register" button show. One request per
# version; cancelled by mistake → cancelada_em, never deleted.
class CreateSolicitacoesAprovacao < ActiveRecord::Migration[8.1]
  def change
    create_table :solicitacoes_aprovacao do |t|
      t.string :uuid, null: false
      t.references :arquivo, null: false, foreign_key: true
      t.references :arquivo_version, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :cancelada_em
      t.integer :cancelada_por_id
      t.timestamps
    end
    add_index :solicitacoes_aprovacao, :uuid, unique: true
  end
end
