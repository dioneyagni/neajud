class MoldePeca < ApplicationRecord
  include ReferenciaAtiva

  belongs_to :molde
  belongs_to :peca
  recusa_excluido :molde, :peca
end
