# Dublagem 5b1a (decided 10/11/2026): the construção becomes a chave of
# dublagens — each base layer keeps in which dublagem (the chave's column)
# it is joined to the layer above. Every construção so far was a stack
# dubbed top to bottom, one dublagem per layer: the 2nd layer in the 1st,
# the 3rd in the 2nd… The limit of layers moves to Parâmetros (Q2d), 8 to
# start (it was a constant 5).
class AdicionaOrdemDaDublagem < ActiveRecord::Migration[8.1]
  def up
    add_column :camadas_construcao, :ordem_da_dublagem, :integer
    execute "UPDATE camadas_construcao SET ordem_da_dublagem = posicao - 1 WHERE posicao > 1"
    add_column :empresas, :maximo_de_camadas, :integer, null: false, default: 8
  end

  def down
    remove_column :empresas, :maximo_de_camadas
    remove_column :camadas_construcao, :ordem_da_dublagem
  end
end
