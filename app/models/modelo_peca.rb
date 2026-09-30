class ModeloPeca < ApplicationRecord
  include ReferenciaAtiva

  belongs_to :modelo
  belongs_to :peca
  recusa_excluido :modelo, :peca
end
