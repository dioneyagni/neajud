class ArquivoMolde < ApplicationRecord
  include ReferenciaAtiva

  belongs_to :arquivo
  belongs_to :molde
  recusa_excluido :arquivo, :molde

  validates :molde_id, uniqueness: { scope: :arquivo_id }
end
