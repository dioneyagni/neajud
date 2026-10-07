class MoldePeca < ApplicationRecord
  include GeraUuid
  include ReferenciaAtiva

  belongs_to :molde
  belongs_to :peca
  recusa_excluido :peca

  validates :peca_id, uniqueness: { scope: :molde_id }
  # Etapa 1.2 (3/3, parte 3b): production counts pieces — pecas_por_par of
  # this part per pair; espelhada splits them half right, half left.
  validates :pecas_por_par, numericality: { only_integer: true, greater_than: 0 }
  validate :espelhada_com_pecas_pares

  scope :for_molde, ->(molde_id) { where(molde_id: molde_id) }

  # Usage: molde_peca.pecas_para(10) # => 20 (2 per pair)
  def pecas_para(pares)
    pares * pecas_por_par
  end

  private

  def espelhada_com_pecas_pares
    return unless espelhada && pecas_por_par.to_i.odd?

    errors.add(:espelhada, "needs an even number of pieces per pair (half right, half left), got #{pecas_por_par}")
  end
end
