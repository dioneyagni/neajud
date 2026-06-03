class ArquivoModelo < ApplicationRecord
  belongs_to :arquivo
  belongs_to :modelo

  validates :modelo_id, uniqueness: { scope: :arquivo_id }
end
