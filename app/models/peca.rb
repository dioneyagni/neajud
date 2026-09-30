class Peca < ApplicationRecord
  include GeraUuid
  include Excluivel

  has_many :arquivos, dependent: :nullify
  has_many :item_pedido_pecas, dependent: :nullify
  has_many :arquivo_vinculo_logs, dependent: :nullify
  has_many :modelo_pecas, dependent: :delete_all
  has_many :modelos, through: :modelo_pecas

  validates :nome, presence: true, uniqueness: { case_sensitive: false }

  scope :search, ->(q) {
    return all if q.blank?
    pattern = "%#{q.to_s.gsub(/[%_]/, '\\\\\0')}%"
    where("nome LIKE ?", pattern)
  }
end
