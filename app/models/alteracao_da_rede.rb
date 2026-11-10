# One line of a ligação's histórico (rede editável 2/2a, decided 10/11/2026,
# Q3a): who, when and what changed, as text written when it was saved — so
# it stays right after a group is renamed. "criou", "mandou para a lixeira"
# and "restaurou" are lines too. A situação's too since 2/2b: "criou",
# "renomeou X → Y".
#
# Usage: ligacao.alteracoes.create!(user: Current.user, texto: "dubla antes → depois")
class AlteracaoDaRede < ApplicationRecord
  self.table_name = "alteracoes_da_rede"

  include GeraUuid
  belongs_to :registro, polymorphic: true
  belongs_to :user, optional: true

  validates :texto, presence: true

  scope :recentes, -> { order(created_at: :desc, id: :desc) }
end
