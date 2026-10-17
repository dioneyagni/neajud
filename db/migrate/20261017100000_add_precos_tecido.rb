# Etapa 2.7b (decided 17/10/2026): the tecido's prices and minimum meters —
# the dono's print price per meter (a client may have his own agreed) and
# minimum per item (the dono's only); each item's edited prices beside the
# starting ones, and the approval of an item below the minimum, valid while
# its meters are the ones approved.
class AddPrecosTecido < ActiveRecord::Migration[8.1]
  def change
    add_column :empresas, :preco_impressao_metro_tecido, :decimal, precision: 10, scale: 2
    add_column :empresas, :metragem_minima_tecido, :decimal, precision: 8, scale: 1
    add_column :clients, :preco_impressao_metro_tecido, :decimal, precision: 10, scale: 2
    change_table :itens_pedido, bulk: true do |t|
      t.decimal :preco_impressao_metro, precision: 10, scale: 2
      t.decimal :preco_impressao_metro_partida, precision: 10, scale: 2
      t.decimal :preco_tecido_metro, precision: 10, scale: 2
      t.decimal :preco_tecido_metro_partida, precision: 10, scale: 2
      t.references :minimo_aprovado_por, foreign_key: { to_table: :users }
      t.datetime :minimo_aprovado_em
      t.decimal :minimo_aprovado_metros, precision: 8, scale: 1
    end
  end
end
