class ModeloPeca < ApplicationRecord
  include ReferenciaAtiva

  belongs_to :modelo
  belongs_to :peca
  recusa_excluido :peca

  validates :peca_id, uniqueness: { scope: :modelo_id }

  scope :for_modelo, ->(modelo_id) { where(modelo_id: modelo_id) }
end
