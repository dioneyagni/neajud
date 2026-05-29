class Peca < ApplicationRecord
  has_many :arquivos, dependent: :nullify
  has_many :molde_pecas, dependent: :destroy
  has_many :moldes, through: :molde_pecas

  validates :nome, presence: true, uniqueness: { case_sensitive: false }

  scope :search, ->(q) {
    return all if q.blank?
    where("nome LIKE ?", "%#{q}%")
  }

  def to_param
    id.to_s
  end
end
