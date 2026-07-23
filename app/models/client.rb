class Client < ApplicationRecord
  has_many :arquivos, dependent: :nullify
  has_many :modelos, dependent: :destroy
  has_many :movimento_estoques, dependent: :destroy
  has_many :pedidos, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :responsible, presence: true

  scope :search, ->(q) {
    return all if q.blank?
    pattern = "%#{q.to_s.gsub(/[%_]/, '\\\\\0')}%"
    where("name LIKE ? OR responsible LIKE ?", pattern, pattern)
  }
end
