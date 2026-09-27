# Etapa 0.4 (docs/plano.md): nothing user-facing is physically deleted any
# more. deleted_by_id/restored_by_id stay empty until Etapa 0.5 creates users;
# until then who did it is the IP in exclusao_logs.changed_by.
class AddExclusaoLogica < ActiveRecord::Migration[8.1]
  TABELAS = %i[arquivos clients modelos moldes pecas pedidos].freeze

  def change
    TABELAS.each do |tabela|
      add_column tabela, :deleted_at, :datetime
      add_column tabela, :deleted_by_id, :integer
      add_column tabela, :restored_at, :datetime
      add_column tabela, :restored_by_id, :integer
      add_index tabela, :deleted_at
    end

    create_table :exclusao_logs do |t|
      t.references :registro, polymorphic: true, null: false
      t.string :acao, null: false
      t.string :registro_rotulo, null: false
      t.string :changed_by
      t.timestamps
    end
  end
end
