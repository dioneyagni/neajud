# Dublagem 3/5 (decided 30/10-02/11/2026, docs/plano.md Etapa 2.9 D6/D7):
# a construção is a saved dublado — the superfície with its lado, the bases
# in order, each layer the empresa's or the construção's client's, the
# ligante that joins each layer to the one above and the situação. It owns a
# material of tipo "dublado" (its stock and price per meter), so the
# duplicate rule of materials leaves dublados out: two construções on the
# same Oxford Preto 1.40 m are two materials. The empresa's service value is
# charged per ligação.
class ConstrucoesDeDublagem < ActiveRecord::Migration[8.1]
  CHAVE = %i[grupo_material_id cor_material_id largura gramatura densidade espessura_mm micras fornecedor].freeze

  def change
    create_table :construcoes do |t|
      t.string :uuid, null: false, index: { unique: true }
      t.string :nome, null: false
      t.references :client, foreign_key: true
      t.string :situacao
      t.references :materia_prima, null: false, foreign_key: true, index: { unique: true }
      t.decimal :preco_final, precision: 10, scale: 2
      t.datetime :deleted_at, index: true
      t.integer :deleted_by_id
      t.datetime :restored_at
      t.integer :restored_by_id
      t.timestamps
    end

    create_table :camadas_construcao do |t|
      t.references :construcao, null: false, foreign_key: true
      t.integer :posicao, null: false
      t.references :materia_prima, null: false, foreign_key: true
      t.boolean :do_cliente, default: false, null: false
      t.string :lado
      t.references :ligante, foreign_key: { to_table: :materia_primas }
      t.timestamps
      t.index %i[construcao_id posicao], unique: true
    end

    add_column :empresas, :preco_servico_dublagem, :decimal, precision: 10, scale: 2

    remove_index :materia_primas, CHAVE, unique: true, name: "idx_materia_primas_composite"
    add_index :materia_primas, CHAVE, unique: true, name: "idx_materia_primas_composite", where: "tipo <> 'dublado'"
  end
end
