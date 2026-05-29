class Tamanho < ApplicationRecord
  belongs_to :arquivo, foreign_key: :arquivo_id
  validates :nome, presence: true
  default_scope { order(:position) }
end
