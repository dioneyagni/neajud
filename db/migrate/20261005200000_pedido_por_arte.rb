# Etapa 1.2 (3/3, parte 1; decided 05/10/2026): a pedido has a type (calçado
# now; DTF and tecido in Fase 2), an item is an arte (the envelope, not one of
# its files) and its grade is by individual size ("29": 4, "30": 6) instead of
# the corte's size name ("29-30": 10).
#
# The existing pedidos are development samples whose grade can't be split by
# number: they go to the trash, marked grade_antiga (read only even if
# restored). Their items get the arte of their file. Rollback brings back only
# what this migration trashed.
class PedidoPorArte < ActiveRecord::Migration[8.1]
  QUEM = "migracao_pedido_por_arte".freeze

  def up
    add_column :pedidos, :tipo, :string, null: false, default: "calcado"
    add_column :pedidos, :grade_antiga, :boolean, null: false, default: false
    add_reference :itens_pedido, :arte, foreign_key: true
    execute "UPDATE itens_pedido SET arte_id = (SELECT arquivos.arte_id FROM arquivos WHERE arquivos.id = itens_pedido.arquivo_id)"
    execute "UPDATE pedidos SET grade_antiga = 1"
    lixeira_para_os_antigos
  end

  def down
    execute <<~SQL
      UPDATE pedidos SET deleted_at = NULL, deleted_by_id = NULL
      WHERE id IN (SELECT registro_id FROM exclusao_logs WHERE registro_type = 'Pedido' AND changed_by = '#{QUEM}')
    SQL
    execute "DELETE FROM exclusao_logs WHERE registro_type = 'Pedido' AND changed_by = '#{QUEM}'"
    remove_reference :itens_pedido, :arte, foreign_key: true
    remove_column :pedidos, :grade_antiga
    remove_column :pedidos, :tipo
  end

  private

  def lixeira_para_os_antigos
    agora = Time.current
    select_rows("SELECT id, uuid FROM pedidos WHERE deleted_at IS NULL").each do |id, uuid|
      execute "UPDATE pedidos SET deleted_at = #{quote(agora)} WHERE id = #{id.to_i}"
      execute <<~SQL
        INSERT INTO exclusao_logs (uuid, registro_type, registro_id, registro_rotulo, acao, changed_by, created_at, updated_at)
        VALUES (#{quote(SecureRandom.uuid)}, 'Pedido', #{id.to_i}, #{quote("Pedido #{uuid.first(8)}")}, 'excluido', '#{QUEM}', #{quote(agora)}, #{quote(agora)})
      SQL
    end
  end

  def quote(valor)
    connection.quote(valor)
  end
end
