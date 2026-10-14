# Etapa 2.6b1 (decided 13/10/2026): the DTF pedido.
# - arquivos.encaixe_dtf: each etiqueta size's fit on the film (copies per
#   row and the row's step, standing and turned), computed when its measure,
#   spacing or the film change — never per pedido;
# - pedidos.entrega (rolo / cortada) and pedidos.fileiras_extras, the
#   pedido's default extra rows (from the dono's parameter);
# - itens_pedido_grade.fileiras_extras: a line's own extra rows (blank =
#   the pedido's), and encaixe_dtf: the fit written when the pedido is
#   confirmed, so a later version or film change never moves its quantities.
class AddPedidoDtf < ActiveRecord::Migration[8.1]
  def change
    add_column :arquivos, :encaixe_dtf, :json
    change_table :pedidos, bulk: true do |t|
      t.string :entrega, default: "rolo", null: false
      t.integer :fileiras_extras, default: 0, null: false
    end
    change_table :itens_pedido_grade, bulk: true do |t|
      t.integer :fileiras_extras
      t.json :encaixe_dtf
    end
  end
end
