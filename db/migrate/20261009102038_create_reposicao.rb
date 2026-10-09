# Etapa 2.2 (4/4, decided 08-09/10/2026): a Conferência with fewer pieces
# than expected puts them in the pedido's open reposição — a sub-pedido of
# the same client, counting the exact pieces missing of each line — which
# goes to production (confirmed) when the Conferência ends or by "Gerar
# reposição".
# - pedidos.reposicao_de: the pedido it repairs;
# - itens_reposicao: one per line that missed pieces (file, part, DXF size,
#   side, material, whether the part cuts, pieces);
# - baixas_producao.contagens: each covered line's count (a group baixa
#   with pieces missing is counted line by line); reposicao: what it made.
class CreateReposicao < ActiveRecord::Migration[8.1]
  def change
    add_reference :pedidos, :reposicao_de, foreign_key: { to_table: :pedidos }

    create_table :itens_reposicao do |t|
      t.string :uuid, null: false
      t.references :pedido, null: false, foreign_key: true
      t.references :item_origem, null: false, foreign_key: { to_table: :itens_pedido }
      t.references :arquivo, null: false, foreign_key: true
      t.references :peca, foreign_key: true
      t.references :tamanho, foreign_key: true
      t.references :materia_prima, foreign_key: true
      t.string :lado
      t.boolean :corta, null: false, default: true
      # What the conferente left checked (decided 09/10/2026): the reposição
      # prints and/or cuts this line again; Estamparia and Conferência always.
      t.boolean :refazer_impressao, null: false, default: true
      t.boolean :refazer_corte, null: false, default: true
      t.integer :pecas, null: false
      t.timestamps
    end
    add_index :itens_reposicao, :uuid, unique: true

    add_column :baixas_producao, :contagens, :json, null: false, default: {}
    add_reference :baixas_producao, :reposicao, foreign_key: { to_table: :pedidos }
  end
end
