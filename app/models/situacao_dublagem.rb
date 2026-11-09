# A situação a construção may be in (plano Etapa 2.9 D6; in the database
# since rede editável 1/2, 09/11/2026, Q1a): it changes the ligantes of the
# ligações that list it. Construcao#situacao keeps its chave.
class SituacaoDublagem < ApplicationRecord
  self.table_name = "situacoes_dublagem"

  include GeraUuid
  has_many :ligantes, class_name: "LiganteDaLigacao", inverse_of: :situacao_dublagem, dependent: :restrict_with_error

  validates :chave, presence: true, uniqueness: true, format: { with: /\A[a-z0-9_]+\z/, message: "%{value} is not a key; expected lowercase letters, digits and _" }
  validates :nome, presence: true

  after_commit { RedeDeDublagens.esquecer }
end
