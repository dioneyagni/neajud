class MovimentoEstoque < ApplicationRecord
  belongs_to :materia_prima
  belongs_to :client

  validates :tipo, presence: true, inclusion: { in: %w[entrada saida] }
  validates :quantidade, presence: true, numericality: { greater_than: 0 }

  scope :entradas, -> { where(tipo: "entrada") }
  scope :saidas, -> { where(tipo: "saida") }
  scope :recentes, -> { order(created_at: :desc) }

  def valor_total
    valor.present? ? quantidade * valor : nil
  end
end
