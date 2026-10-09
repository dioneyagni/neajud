# Etapa 2.4 (calçado, decided 09/10/2026): a pedido de calçado is charged per
# pair, at the molde's price for that number (bands of the produto's grade);
# the price is written into each grade row when the pedido is confirmed. The
# cost per pair comes from two of the dono's parameters — printing per meter
# (paper, ink and machine) and cutting per piece. The new action
# "ver_valores" shows prices and costs; the Admin função gets it, like
# atualizar_producao (20261008154800).
class PrecosDoMoldeECustosDoDono < ActiveRecord::Migration[8.1]
  class Funcao < ActiveRecord::Base
    self.table_name = "funcoes"
  end

  def up
    create_table :faixas_de_preco do |t|
      t.references :molde, null: false, foreign_key: true
      t.string :tamanho_inicial, null: false
      t.string :tamanho_final, null: false
      t.decimal :preco_par, precision: 10, scale: 2, null: false
      t.string :uuid, null: false
      t.timestamps
    end
    add_index :faixas_de_preco, :uuid, unique: true

    add_column :empresas, :custo_impressao_metro, :decimal, precision: 10, scale: 2
    add_column :empresas, :custo_corte_peca, :decimal, precision: 10, scale: 4
    add_column :itens_pedido_grade, :preco_par, :decimal, precision: 10, scale: 2

    Funcao.where(nome: "Admin", dono: false).find_each do |funcao|
      funcao.update_columns(acoes: Array(funcao.acoes) | [ "ver_valores" ])
    end
  end

  def down
    Funcao.where(nome: "Admin", dono: false).find_each do |funcao|
      funcao.update_columns(acoes: Array(funcao.acoes) - [ "ver_valores" ])
    end

    remove_column :itens_pedido_grade, :preco_par
    remove_column :empresas, :custo_corte_peca
    remove_column :empresas, :custo_impressao_metro
    drop_table :faixas_de_preco
  end
end
