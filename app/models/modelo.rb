class Modelo < ApplicationRecord
  include GeraUuid
  include Excluivel

  has_many :arquivos, dependent: :nullify
  has_many :moldes, dependent: :nullify
  has_many :modelo_pecas, dependent: :delete_all
  has_many :pecas, through: :modelo_pecas

  validates :nome, presence: true, uniqueness: { case_sensitive: false }

  scope :search, ->(q) {
    return all if q.blank?
    pattern = "%#{q.to_s.gsub(/[%_]/, '\\\\\0')}%"
    where("nome LIKE ?", pattern)
  }
end
