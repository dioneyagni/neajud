class ModeloPeca < ApplicationRecord
  belongs_to :modelo
  belongs_to :peca

  validates :peca_id, uniqueness: { scope: :modelo_id }

  scope :for_modelo, ->(modelo_id) { where(modelo_id: modelo_id) }
end
