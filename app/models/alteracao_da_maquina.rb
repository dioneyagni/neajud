# One line of a machine's histórico (Máquinas 1/5): who, when and what
# changed, as text written when it was saved ("criou com Calandra 40 m/h",
# "acrescentou Dublagem 30 m/h"), so it stays right after a rename. Trash
# and restore are lines too — and, as their only commit (Excluivel writes
# with update_columns), they are what refreshes the Painel then.
#
# Usage: maquina.alteracoes.create!(user: Current.user, texto: "tirou Dublagem")
class AlteracaoDaMaquina < ApplicationRecord
  self.table_name = "alteracoes_da_maquina"

  include GeraUuid
  include AvisaAFila
  belongs_to :maquina, inverse_of: :alteracoes
  belongs_to :user, optional: true

  validates :texto, presence: true

  scope :recentes, -> { order(created_at: :desc, id: :desc) }
end
