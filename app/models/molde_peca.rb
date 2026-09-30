class MoldePeca < ApplicationRecord
  include GeraUuid
  include ReferenciaAtiva

  belongs_to :molde
  belongs_to :peca
  recusa_excluido :peca

  validates :peca_id, uniqueness: { scope: :molde_id }

  scope :for_molde, ->(molde_id) { where(molde_id: molde_id) }
end
