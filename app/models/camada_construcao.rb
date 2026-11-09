# One layer of a Construcao (Dublagem 3/5, decided 30/10-02/11/2026): the
# superfície at position 1, with its lado (trama or avesso), then the bases
# in order. Each says whether it is the empresa's or the construção's
# client's, and the ligante that joins it to the layer above — none on the
# superfície, none either where no registered material serves yet (the cola,
# until 5/5). A base keeps when its ligação dubs (dubla: antes | depois,
# rede editável 1/2, Q3a; Construcao#guardar_momentos). Addressed by
# position inside its construção, so no uuid.
class CamadaConstrucao < ApplicationRecord
  self.table_name = "camadas_construcao"

  belongs_to :construcao, inverse_of: :camadas
  belongs_to :materia_prima
  belongs_to :ligante, class_name: "MateriaPrima", optional: true

  # Only the superfície has a side; only the layers below it a ligante.
  before_validation { self.lado = nil unless superficie? }
  before_validation { self.ligante = nil if superficie? }
  before_validation { self.dubla = nil if superficie? }

  validates :posicao, inclusion: { in: 1..Construcao::MAXIMO_DE_CAMADAS, message: "%{value} is not a layer position; expected 1 to #{Construcao::MAXIMO_DE_CAMADAS}" }
  validates :dubla, inclusion: { in: RedeDeDublagens::DUBLA, message: "%{value} is not a momento; expected #{RedeDeDublagens::DUBLA.join(" or ")}" }, allow_nil: true
  validates :lado, inclusion: { in: RedeDeDublagens::LADOS, message: "%{value} is not a side; expected #{RedeDeDublagens::LADOS.join(" or ")}" }, if: :superficie?

  def superficie? = posicao == 1

  # The network's ligação between this layer and the material under it —
  # the superfície's lado first; nil when they don't dub.
  # Usage: superficie.ligacao_com(lona).dubla # => "antes"
  def ligacao_com(material_abaixo)
    RedeDeDublagens.ligacao(materia_prima.grupo_material.nome, material_abaixo.grupo_material.nome, lado: (lado if superficie?))
  end

  # What makes two layers the same, for the duplicate construção check.
  def identidade = [ posicao, materia_prima_id, do_cliente, lado, ligante_id ]
end
