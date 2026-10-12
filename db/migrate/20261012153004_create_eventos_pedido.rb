# Etapa 2.8 (5/5, decided 12/10/2026): the cliente final builds his draft and
# sends it to the factory (status "enviado"); he may take it back while it
# isn't confirmed, and the team may return it with a note. Each step is an
# EventoPedido — the pedido's history. The default "Cliente final" gets
# pedidos: editar.
class CreateEventosPedido < ActiveRecord::Migration[8.1]
  class Funcao < ActiveRecord::Base
    self.table_name = "funcoes"
  end

  class Pedido < ActiveRecord::Base
    self.table_name = "pedidos"
  end

  NOME = "Cliente final".freeze

  def up
    create_table :eventos_pedido do |t|
      t.string :uuid, null: false
      t.references :pedido, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :tipo, null: false
      t.text :recado
      t.timestamps
    end
    add_index :eventos_pedido, :uuid, unique: true

    nivel_do_padrao(2)
  end

  # A pedido waiting for the factory goes back to a draft: the status
  # doesn't exist before this migration.
  def down
    Pedido.where(status: "enviado").update_all(status: "rascunho")
    nivel_do_padrao(1)
    drop_table :eventos_pedido
  end

  private

  def nivel_do_padrao(nivel)
    funcao = Funcao.find_by(nome: NOME, para_cliente: true)
    funcao&.update!(niveis: funcao.niveis.to_h.merge("pedidos" => nivel))
  end
end
