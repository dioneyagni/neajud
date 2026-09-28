# Etapa 0.5 (3/4): users managed by whoever may "gerenciar usuários".
# trocar_senha: set with a provisional password, forces a change at the next
# sign-in. Deactivating (never deleting — docs/plano.md) blocks sign-in and
# keeps the person in lists and history.
class AddGestaoToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :trocar_senha, :boolean, null: false, default: false
    add_column :users, :desativado_em, :datetime
    add_column :users, :desativado_por_id, :integer
  end
end
