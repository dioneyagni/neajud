class CorMaterial < ApplicationRecord
  has_many :materia_primas, dependent: :restrict_with_error

  validates :nome, presence: true, uniqueness: { case_sensitive: false }
end
