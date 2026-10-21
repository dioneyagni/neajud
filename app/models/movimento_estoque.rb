# One entry or exit of a material, in meters (Etapa 2.3). Without client it
# is the empresa's own stock; with one, that client's material kept here.
class MovimentoEstoque < ApplicationRecord
  include GeraUuid
  include ReferenciaAtiva

  belongs_to :materia_prima
  belongs_to :client, optional: true
  # Etapa 2.3d2: a pedido's stock out (SaidaDoPedido); nil for one by hand.
  belongs_to :pedido, optional: true
  # Etapa 2.3e: the baixa whose real metragem this adjusts (AjusteDaBaixa).
  belongs_to :baixa_producao, optional: true
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
  # What the balances count (Etapa 2.3d2): a trashed pedido's outs don't —
  # restoring it brings them back. Etapa 2.3e: neither does an undone baixa's
  # adjustment (redone, the new baixa makes its own).
  scope :que_contam, lambda {
    where(pedido_id: nil).or(where(pedido_id: Pedido.where(deleted_at: nil).select(:id)))
                         .merge(where(baixa_producao_id: nil).or(where(baixa_producao_id: BaixaProducao.vigentes.select(:id))))
  }
  # A pedido's out at confirmation, not an adjustment (Etapa 2.3e).
  scope :da_confirmacao, -> { saidas.where.not(pedido_id: nil).where(baixa_producao_id: nil) }

  # Why this movement no longer counts, or nil (Etapa 2.3e; shown in the ledger).
  # Usage: movimento.motivo_de_nao_contar # => "baixa desfeita"
  def motivo_de_nao_contar
    return "na lixeira" if pedido&.excluido?

    "baixa desfeita" if baixa_producao&.desfeita_em
  end

  # Usage: movimento.dono # => "Empresa" or the client's name
  def dono
    client&.name || "Empresa"
  end

  def valor_total
    valor.present? ? quantidade * valor : nil
  end
end
