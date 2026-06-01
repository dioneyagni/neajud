class Molde < ApplicationRecord
  has_many :arquivos, dependent: :nullify
  has_many :modelos, dependent: :nullify
  has_many :molde_pecas, dependent: :delete_all
  has_many :pecas, through: :molde_pecas

  validates :nome, presence: true, uniqueness: { case_sensitive: false }

  scope :search, ->(q) {
    return all if q.blank?
    where("nome LIKE ?", "%#{q}%")
  }

  def to_param
    id.to_s
  end
end
