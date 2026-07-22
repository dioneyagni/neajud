class Peca < ApplicationRecord
  has_many :arquivos, dependent: :nullify
  has_many :molde_pecas, dependent: :delete_all
  has_many :moldes, through: :molde_pecas

  validates :nome, presence: true, uniqueness: { case_sensitive: false }

  scope :search, ->(q) {
    return all if q.blank?
    pattern = "%#{q.to_s.gsub(/[%_]/, '\\\\\0')}%"
    where("nome LIKE ?", pattern)
  }

  def to_param
    id.to_s
  end
end
