# Etapa 2.3d1 (decided 19/10/2026): whose fabric a pedido takes cascades
# cliente → molde → pedido, blank = inherit; the pedido's paper or DTF film
# may differ from the empresa's default, and the DTF film becomes a material.
class DonoDoTecidoEmCascata < ActiveRecord::Migration[8.1]
  def up
    add_column :clients, :dono_tecido, :string
    add_column :moldes, :dono_tecido, :string
    add_column :itens_pedido, :dono_tecido, :string
    change_column_default :pedidos, :dono_tecido, from: "cliente", to: nil
    change_column_null :pedidos, :dono_tecido, true
    # A draft inherits from now on; a confirmed pedido keeps what it had,
    # written on its items too (what confirming writes from now on).
    execute "UPDATE pedidos SET dono_tecido = NULL WHERE status IN ('rascunho', 'enviado')"
    execute <<~SQL
      UPDATE itens_pedido SET dono_tecido = (SELECT pedidos.dono_tecido FROM pedidos WHERE pedidos.id = itens_pedido.pedido_id)
      WHERE pedido_id IN (SELECT id FROM pedidos WHERE dono_tecido IS NOT NULL)
    SQL
    add_reference :pedidos, :material_impressao, foreign_key: { to_table: :materia_primas }
    add_reference :empresas, :filme_dtf_padrao, foreign_key: { to_table: :materia_primas }
  end

  def down
    remove_reference :empresas, :filme_dtf_padrao, foreign_key: { to_table: :materia_primas }
    remove_reference :pedidos, :material_impressao, foreign_key: { to_table: :materia_primas }
    execute "UPDATE pedidos SET dono_tecido = 'cliente' WHERE dono_tecido IS NULL"
    change_column_null :pedidos, :dono_tecido, false
    change_column_default :pedidos, :dono_tecido, from: nil, to: "cliente"
    remove_column :itens_pedido, :dono_tecido
    remove_column :moldes, :dono_tecido
    remove_column :clients, :dono_tecido
  end
end
