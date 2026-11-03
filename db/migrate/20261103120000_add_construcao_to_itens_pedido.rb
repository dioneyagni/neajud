# Dublagem 4/5 (decided 02/11/2026, docs/plano.md Etapa 2.9 D1): a tecido
# item keeps its superfície (materia_prima, where the arte is printed) and
# may name a construção to be dubbed into; blank = no dublagem.
class AddConstrucaoToItensPedido < ActiveRecord::Migration[8.1]
  def change
    add_reference :itens_pedido, :construcao, foreign_key: true
  end
end
