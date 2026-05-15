class Tamanho < ApplicationRecord
  belongs_to :stamp
  validates :nome, presence: true
  default_scope { order(:position) }
end
