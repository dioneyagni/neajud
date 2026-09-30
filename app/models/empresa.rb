# The company this instance serves. One instance per empresa (docs/plano.md,
# Etapa 3.1), so there is at most one row and data tables carry no empresa_id.
class Empresa < ApplicationRecord
  include GeraUuid

  has_many :vinculos, dependent: :destroy

  validates :nome, presence: true
  validate :unica_por_instancia, on: :create

  # Usage: Empresa.atual&.nome
  def self.atual
    first
  end

  private

  def unica_por_instancia
    return unless Empresa.exists?

    errors.add(:base, "this instance already has an empresa (\"#{Empresa.atual.nome}\"); expected at most one")
  end
end
