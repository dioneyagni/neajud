# A saved dublado (Dublagem 3/5, decided 30/10-02/11/2026; plano Etapa 2.9
# D6/D7): the superfície with its lado, the bases in order, the ligante of
# each ligação and the situação. It owns a material of tipo "dublado"
# (decision 1) — the superfície's group and color, the narrowest layer's
# width (decision 3), priced at the construção's final price — so the stock
# and the pedido reuse what materials already do. A layer is the empresa's
# or the construção's client's (decision 2); with a client, the construção
# and its dublado are that client's. Everything changes until the dublado is
# used — a stock movement or a pedido item —, then only the final price
# (decision 5). The rules come from config/dublagens.yml (RegrasDaConstrucao).
#
# Usage: construcao = Construcao.new(situacao: "tecido_molha", preco_final: 46)
#        construcao.definir_camadas([ { materia_prima: oxford, lado: "trama" }, { materia_prima: lona, ligante: filme_pu } ])
#        construcao.save # => creates the dublado "Oxford Preto / Lona Branco-1.40 m (Tecido molha)"
class Construcao < ApplicationRecord
  MAXIMO_DE_CAMADAS = 5

  include GeraUuid
  include Excluivel
  include ReferenciaAtiva
  belongs_to :client, optional: true
  belongs_to :materia_prima, autosave: true
  has_many :camadas, -> { order(:posicao) }, class_name: "CamadaConstrucao", inverse_of: :construcao, dependent: :destroy, autosave: true
  atribui_por_uuid :client
  recusa_excluido :client

  normalizes :situacao, with: ->(situacao) { situacao.presence }

  before_validation :montar_dublado
  validates :situacao, inclusion: { in: ->(_) { RedeDeDublagens.situacoes.keys }, message: "%{value} is not a situação; expected one of #{RedeDeDublagens.situacoes.keys.join(", ")}" }, allow_nil: true
  validates :preco_final, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :regras_da_rede
  validate :composicao_fixa_em_uso, on: :update

  # Sets the layers by position, keeping the rows already there (only what
  # changed is saved); positions past the list are removed.
  # Usage: construcao.definir_camadas([ { materia_prima: oxford, lado: "avesso" }, { materia_prima: eva, ligante: filme_25 } ])
  def definir_camadas(lista)
    lista.each.with_index(1) do |dados, posicao|
      camada = camadas.find { |existente| existente.posicao == posicao } || camadas.build(posicao: posicao)
      camada.assign_attributes(dados)
    end
    camadas.each { |camada| camada.mark_for_destruction if camada.posicao > lista.size }
  end

  # The layers being kept, top to bottom.
  def camadas_em_ordem = camadas.reject(&:marked_for_destruction?).sort_by(&:posicao)

  def superficie = camadas_em_ordem.first

  # Usage: construcao.ligacoes # => 2 (three layers)
  def ligacoes = [ camadas_em_ordem.size - 1, 0 ].max

  # Its dublado already counts somewhere: the layers stay as they are.
  def em_uso? = persisted? && materia_prima.persisted? && materia_prima.em_uso?

  def situacao_rotulo = situacao && RedeDeDublagens.situacoes[situacao]

  # Never the client's name: the dublado is a material, and every client
  # reads the list of materials (Visibilidade::COMUNS).
  # Usage: "Oxford Preto (avesso) / Espuma TC4 3 mm Branco-1.40 m (Tecido molha)"
  def nome_montado
    nomes = camadas_em_ordem.select(&:materia_prima).map { |camada| nome_da_camada(camada) }
    [ "#{nomes.join(" / ")}-#{largura_mais_estreita}", situacao_rotulo && "(#{situacao_rotulo})" ].compact.join(" ")
  end

  # The narrowest layer's width, the dublado's (decision 3).
  def largura_mais_estreita
    camadas_em_ordem.filter_map(&:materia_prima).min_by { |material| material.largura_mm || Float::INFINITY }&.largura
  end

  private

  def nome_da_camada(camada)
    camada.lado == "avesso" ? "#{camada.materia_prima.nome_da_camada} (avesso)" : camada.materia_prima.nome_da_camada
  end

  def montar_dublado
    superficie_material = superficie&.materia_prima
    return unless superficie_material

    self.nome = nome_montado
    (self.materia_prima ||= MateriaPrima.new).assign_attributes(tipo: "dublado", grupo_material: superficie_material.grupo_material,
                                                                cor_material: superficie_material.cor_material, largura: largura_mais_estreita, preco_metro: preco_final)
  end

  def regras_da_rede
    RegrasDaConstrucao.new(self).erros.each { |erro| errors.add(:base, erro) }
  end

  def composicao_fixa_em_uso
    return unless MateriaPrima.find(materia_prima_id_in_database).em_uso?
    return unless will_save_change_to_situacao? || will_save_change_to_client_id? || camadas.any? { |camada| camada.new_record? || camada.marked_for_destruction? || camada.changed? }

    errors.add(:base, "#{nome_in_database} já está em uso (estoque ou pedido): só o preço final muda; para outra composição, crie outra construção")
  end
end
