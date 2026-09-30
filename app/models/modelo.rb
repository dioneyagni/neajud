# A style category (Tenis [TNS], Jogging [JGG]) under a Produto, from the
# official Neajud list (config/catalogo_oficial.yml — Etapa 1.1, 3/5): read
# only for the company. It has no parts: those belong to each molde.
# produto is nil only for development samples from before the list, which the
# loader sends to the trash.
class Modelo < ApplicationRecord
  include GeraUuid
  include Excluivel

  belongs_to :produto, optional: true
  has_many :arquivos, dependent: :nullify
  has_many :moldes, dependent: :nullify

  validates :nome, presence: true, uniqueness: { case_sensitive: false }
  validates :abreviacao, uniqueness: true, allow_nil: true

  delegate :grade, to: :produto, allow_nil: true

  scope :search, ->(q) {
    return all if q.blank?
    pattern = "%#{q.to_s.gsub(/[%_]/, '\\\\\0')}%"
    where("nome LIKE ?", pattern)
  }
end
