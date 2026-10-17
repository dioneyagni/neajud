# Etapa 2.7a (decided 16/10/2026): the tecido pedido — an item is an arte on
# a material, in linear meters (one decimal) on a width (blank = the
# material's); the fabric is the client's or the empresa's, once for the
# whole pedido.
class AddPedidoTecido < ActiveRecord::Migration[8.1]
  def change
    add_column :itens_pedido, :metros, :decimal, precision: 8, scale: 1
    add_column :itens_pedido, :largura_mm, :integer
    add_column :pedidos, :dono_tecido, :string, default: "cliente", null: false
  end
end
