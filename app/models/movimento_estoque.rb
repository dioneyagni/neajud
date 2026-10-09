# One entry or exit of a material, in meters (Etapa 2.3). Without client it
# is the empresa's own stock; with one, that client's material kept here.
class MovimentoEstoque < ApplicationRecord
  include GeraUuid
  include ReferenciaAtiva

  belongs_to :materia_prima
  belongs_to :client, optional: true
  atribui_por_uuid :client
  recusa_excluido :client

  # Marked on the form ("Dono: Empresa"), so a forgotten client never turns
  # into the empresa's stock by accident.
  attribute :da_empresa, :boolean, default: false
  validates :client, presence: { message: "is missing: choose the client, or mark the material as the empresa's" }, unless: :da_empresa

  validates :tipo, presence: true, inclusion: { in: %w[entrada saida] }
  validates :quantidade, presence: true, numericality: { greater_than: 0 }

  scope :entradas, -> { where(tipo: "entrada") }
  scope :saidas, -> { where(tipo: "saida") }
  scope :recentes, -> { order(created_at: :desc) }

  # Usage: movimento.dono # => "Empresa" or the client's name
  def dono
    client&.name || "Empresa"
  end

  def valor_total
    valor.present? ? quantidade * valor : nil
  end
end
