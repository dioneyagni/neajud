class Modelo < ApplicationRecord
  belongs_to :client
  belongs_to :molde, optional: true
  has_many :arquivos, dependent: :nullify
  has_many :arquivo_modelos, dependent: :destroy
  has_many :vinculated_arquivos, through: :arquivo_modelos, source: :arquivo

  validates :nome, presence: true
  validates :nome, uniqueness: { scope: :client_id, case_sensitive: false }

  scope :search, ->(q) {
    return all if q.blank?
    where("nome LIKE ?", "%#{q}%")
  }

  scope :for_client, ->(client_id) {
    where(client_id: client_id)
  }

  def to_param
    id.to_s
  end
end
