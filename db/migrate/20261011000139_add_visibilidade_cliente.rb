# Etapa 2.8 (3a, decided 10/10/2026): what a cliente final sees, by kind
# (TiposParaCliente) — the empresa's default grid, set by the dono, and each
# client's exceptions. Empty = the defaults: nothing to backfill.
class AddVisibilidadeCliente < ActiveRecord::Migration[8.1]
  def change
    add_column :empresas, :visibilidade_cliente, :json, default: {}, null: false
    add_column :clients, :visibilidade, :json, default: {}, null: false
  end
end
