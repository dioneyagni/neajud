class ArquivoModelo < ApplicationRecord
  include ReferenciaAtiva

  belongs_to :arquivo
  belongs_to :modelo
  recusa_excluido :arquivo, :modelo

  validates :modelo_id, uniqueness: { scope: :arquivo_id }
end
