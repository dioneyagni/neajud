class GrupoMaterial < ApplicationRecord
  has_many :materia_primas, dependent: :restrict_with_error

  validates :nome, presence: true, uniqueness: { case_sensitive: false }

  scope :search, ->(q) {
    return all if q.blank?
    where("nome LIKE ?", "%#{q}%")
  }
end
