# A baixa of a production stage (Etapa 2.2, 2/3; decided 07/10/2026): the
# lines it covered (LinhasDeProducao keys), the measure typed and what the
# files expected. Granular by choice — one line, a referência (an arte of the
# pedido) or the whole pedido — and a bigger level covers only the lines
# still open. fora_da_faixa: confirmed although outside the dono's band.
# Undoing (desfeita_em) comes in 3/3.
#
# Usage: pedido.baixas_producao.vigentes.da_etapa("corte").feitas # => #<Set {"8f3a…/2b1c…/9d0e…"}>
class BaixaProducao < ApplicationRecord
  self.table_name = "baixas_producao"
  include GeraUuid

  NIVEIS = EtapasProducao::NIVEIS

  belongs_to :pedido
  belongs_to :user, optional: true
  belongs_to :desfeita_por, class_name: "User", optional: true
  # Etapa 2.2 (4/4): the reposição a Conferência with pieces missing made.
  belongs_to :reposicao, class_name: "Pedido", optional: true

  validates :etapa, presence: true
  validates :nivel, inclusion: { in: NIVEIS, message: "%{value} is not a level; expected #{NIVEIS.join(", ")}" }
  validates :medida, numericality: { greater_than_or_equal_to: 0 }
  validate :cobre_alguma_linha

  scope :vigentes, -> { where(desfeita_em: nil) }
  scope :da_etapa, ->(etapa) { where(etapa: etapa.to_s) }

  # The line keys these baixas covered.
  def self.feitas
    pluck(:linhas).flatten.to_set
  end

  private

  def cobre_alguma_linha
    errors.add(:linhas, "can't be empty: a baixa covers at least one production line") if Array(linhas).empty?
  end
end
