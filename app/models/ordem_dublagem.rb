# An ordem de dublagem (Dublagem 5a, decided 03-04/11/2026; plano Etapa 2.9
# D1/D6): it makes a construção's dublado for the stock, when every ligação
# dubs before the estampa, gathering what several pedidos miss
# (DublagensEmAberto). The operator generates it with the meters to make
# (the missing ones, or more for the stock), then marks it done with the
# real meters — each layer and ligante out, 1 m per meter, from its owner,
# and the dublado in, from the construção's (decision 2a) — or cancels it,
# the stock untouched. A missing component never blocks (decision 4a): its
# balance goes negative, as a baixa's does. Never deleted.
#
# Usage: ordem = OrdemDublagem.create!(construcao: construcao, metros: 23, gerada_por: user)
#        ordem.marcar_feita!(metros: 22.5, user: user)
#        ordem.cancelar!(user: user)
class OrdemDublagem < ApplicationRecord
  self.table_name = "ordens_dublagem"
  STATUS = %w[gerada feita cancelada].freeze

  include GeraUuid
  belongs_to :construcao, inverse_of: :ordens_dublagem
  # The dublado's owner, the construção's; nil = the empresa's.
  belongs_to :client, optional: true
  belongs_to :gerada_por, class_name: "User", optional: true
  belongs_to :feita_por, class_name: "User", optional: true
  belongs_to :cancelada_por, class_name: "User", optional: true
  has_many :movimentos_estoque, class_name: "MovimentoEstoque", inverse_of: :ordem_dublagem, dependent: nil

  scope :geradas, -> { where(status: "gerada") }
  scope :feitas, -> { where(status: "feita") }
  scope :canceladas, -> { where(status: "cancelada") }

  before_validation(on: :create) { self.client = construcao&.client }
  validates :status, inclusion: { in: STATUS, message: "%{value} is not an ordem's status; expected one of #{STATUS.join(", ")}" }
  validates :metros, numericality: { greater_than: 0, message: "must be more than 0 m (got %{value})" }
  validates :metros_feitos, numericality: { greater_than: 0, message: "must be more than 0 m (got %{value})" }, if: -> { status == "feita" }
  validate :construcao_que_dubla_antes, on: :create

  def gerada? = status == "gerada"

  # Usage: ordem.marcar_feita!(metros: 22.5, user: Current.user)
  def marcar_feita!(metros:, user:)
    exigir_gerada!("marked done")
    transaction do
      update!(status: "feita", metros_feitos: metros, feita_por: user, feita_em: Time.current)
      lancar_movimentos!
    end
  end

  # Usage: ordem.cancelar!(user: Current.user)
  def cancelar!(user:)
    exigir_gerada!("cancelled")
    update!(status: "cancelada", cancelada_por: user, cancelada_em: Time.current)
  end

  private

  def exigir_gerada!(acao)
    return if gerada?

    errors.add(:status, "is #{status}: only a generated ordem can be #{acao}")
    raise ActiveRecord::RecordInvalid, self
  end

  def lancar_movimentos!
    ComponentesDaDublagem.new(construcao).each do |componente|
      lancar!(componente.materia_prima, componente.client, "saida", metros_feitos * componente.por_metro)
    end
    lancar!(construcao.materia_prima, client, "entrada", metros_feitos)
  end

  def lancar!(material, dono, tipo, quantidade)
    movimentos_estoque.create!(materia_prima: material, client: dono, da_empresa: dono.nil?, tipo: tipo, quantidade: quantidade.round(4))
  end

  # A construção dubbed after the estampa is the pedido's own (5b), never
  # the stock's.
  def construcao_que_dubla_antes
    return if construcao.nil? || construcao.dubla_antes?

    errors.add(:construcao, "\"#{construcao.nome}\" (#{construcao.uuid}) doesn't dub wholly before the estampa (#{construcao.momentos_da_dublagem.join(", ")}): its dublado isn't made for the stock")
  end
end
