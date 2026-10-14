# Etapa 2.6c (decided 13-14/10/2026): charging the DTF.
# - empresas / clients: the price per meter and per unit cut, how a pedido is
#   charged (metro / quantidade) and whether the excess is (a client's blank
#   follows the dono's: the cascade dono → cliente → pedido);
# - arquivos: each etiqueta size's unit price, calculated from the price per
#   meter and its fit (kept up to date), and the one agreed over it;
# - pedidos / itens_pedido_grade: the pedido's choices and edited prices
#   (blank follows the cascade), and at confirmation the starting price
#   (_partida) next to the one charged, to measure the discount.
class AddPrecosDtf < ActiveRecord::Migration[8.1]
  def change
    change_table :empresas, bulk: true do |t|
      t.decimal :preco_metro_dtf, precision: 10, scale: 2
      t.decimal :preco_corte_dtf, precision: 10, scale: 4
      t.string :cobranca_dtf, default: "quantidade", null: false
      t.boolean :cobrar_excedente_dtf, default: true, null: false
    end
    change_table :clients, bulk: true do |t|
      t.decimal :preco_metro_dtf, precision: 10, scale: 2
      t.decimal :preco_corte_dtf, precision: 10, scale: 4
      t.string :cobranca_dtf
      t.boolean :cobrar_excedente_dtf
    end
    change_table :arquivos, bulk: true do |t|
      t.decimal :preco_unidade_calculado, precision: 10, scale: 2
      t.decimal :preco_unidade_combinado, precision: 10, scale: 2
    end
    change_table :pedidos, bulk: true do |t|
      t.string :cobranca_dtf
      t.boolean :cobrar_excedente
      t.decimal :preco_metro, precision: 10, scale: 2
      t.decimal :preco_metro_partida, precision: 10, scale: 2
      t.decimal :preco_corte, precision: 10, scale: 4
      t.decimal :preco_corte_partida, precision: 10, scale: 4
    end
    change_table :itens_pedido_grade, bulk: true do |t|
      t.decimal :preco_unidade, precision: 10, scale: 2
      t.decimal :preco_unidade_partida, precision: 10, scale: 2
    end
  end
end
