# A saved dublado (Dublagem 3/5, decided 30/10-02/11/2026; plano Etapa 2.9
# D6/D7): the superfície with its lado, the bases in order, the ligante of
# each ligação and the situação. It owns a material of tipo "dublado"
# (decision 1) — the superfície's group and color, the narrowest layer's
# width (decision 3), priced at the construção's final price — so the stock
# and the pedido reuse what materials already do. A layer is the empresa's
# or the construção's client's (decision 2); with a client, the construção
# and its dublado are that client's. Everything changes until the dublado is
# used — a stock movement or a pedido item —, then only the final price
# (decision 5). The rules come from the dublagem network (RegrasDaConstrucao);
# each base layer keeps when its ligação dubs, from the network as it was
# when saved (rede editável 1/2, Q3a).
#
# Usage: construcao = Construcao.new(situacao: "tecido_molha", preco_final: 46)
#        construcao.definir_camadas([ { materia_prima: oxford, lado: "trama" }, { materia_prima: lona, ligante: filme_pu } ])
#        construcao.save # => creates the dublado "Oxford Preto / Lona Branco-1.40 m (Tecido molha)"
class Construcao < ApplicationRecord
  include GeraUuid
  include Excluivel
  include ReferenciaAtiva
  belongs_to :client, optional: true
  belongs_to :materia_prima, autosave: true
  has_many :camadas, -> { order(:posicao) }, class_name: "CamadaConstrucao", inverse_of: :construcao, dependent: :destroy, autosave: true
  # Dublagem 4/5: the pedido items dubbed into it.
  has_many :itens_pedido, class_name: "ItemPedido", inverse_of: :construcao, dependent: nil
  # Dublagem 5a: the ordens that make its dublado.
  has_many :ordens_dublagem, class_name: "OrdemDublagem", inverse_of: :construcao, dependent: nil
  atribui_por_uuid :client
  recusa_excluido :client

  # The construções whose superfície (the top layer) is the material.
  # Usage: Construcao.sobre(oxford).do_cliente_ou_da_empresa(pedido.client)
  scope :sobre, ->(material) { where(id: CamadaConstrucao.where(posicao: 1, materia_prima: material).select(:construcao_id)) }
  # The empresa's and the client's (nil = the empresa's only): what a
  # pedido of that client may be dubbed into (4/5, decision 3).
  scope :do_cliente_ou_da_empresa, ->(client) { where(client_id: [ nil, client&.id ].uniq) }

  normalizes :situacao, with: ->(situacao) { situacao.presence }

  before_validation :montar_dublado
  before_validation :guardar_momentos
  # The message reads the situações when it is given: they are in the database.
  validates :situacao, inclusion: { in: ->(_) { RedeDeDublagens.situacoes.keys },
                                    message: ->(_, dados) { "#{dados[:value]} is not a situação; expected one of #{RedeDeDublagens.situacoes.keys.join(", ")}" } }, allow_nil: true
  validates :preco_final, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validate :regras_da_rede
  validate :composicao_fixa_em_uso, on: :update

  # The most layers a construção may have: Parâmetros' (Dublagem 5b1a, Q2d).
  # Usage: Construcao.maximo_de_camadas # => 8
  def self.maximo_de_camadas = Empresa.atual&.maximo_de_camadas || Empresa.column_defaults["maximo_de_camadas"]

  # Sets the layers by position, keeping the rows already there (only what
  # changed is saved); positions past the list are removed. A base without
  # ordem_da_dublagem given is dubbed in order, top to bottom, as every
  # construção was before the chave (5b1a); the form always gives it.
  # Usage: construcao.definir_camadas([ { materia_prima: oxford, lado: "avesso" }, { materia_prima: eva, ligante: filme_25 } ])
  def definir_camadas(lista)
    lista.each.with_index(1) do |dados, posicao|
      camada = camadas.find { |existente| existente.posicao == posicao } || camadas.build(posicao: posicao)
      camada.assign_attributes({ ordem_da_dublagem: (posicao - 1 if posicao > 1) }.merge(dados))
    end
    camadas.each { |camada| camada.mark_for_destruction if camada.posicao > lista.size }
  end

  # The layers being kept, top to bottom.
  def camadas_em_ordem = camadas.reject(&:marked_for_destruction?).sort_by(&:posicao)

  def superficie = camadas_em_ordem.first

  # Its dublagens as a chave (5b1a), read from the layers as they are now.
  def chave = ChaveDaConstrucao.new(self)

  # Usage: construcao.ligacoes # => 2 (three layers)
  def ligacoes = [ camadas_em_ordem.size - 1, 0 ].max

  # Its dublado already counts somewhere — a stock movement, a pedido item
  # on the dublado or (4/5) one dubbed into it: the layers stay as they are.
  def em_uso? = persisted? && (itens_pedido.exists? || (materia_prima.persisted? && materia_prima.em_uso?))

  def situacao_rotulo = situacao && RedeDeDublagens.situacoes[situacao]

  # When each ligação dubs, against the estampa (D8: "antes" or "depois"),
  # each once, top to bottom; a pair the network doesn't have is left out.
  # In use, as each layer kept it when saved (Q3a); otherwise the network's
  # now, as the next save will keep it.
  # Usage: construcao.momentos_da_dublagem # => ["antes", "depois"]
  def momentos_da_dublagem
    return camadas_em_ordem.drop(1).filter_map(&:dubla).uniq if em_uso?

    camadas_em_ordem.each_cons(2).filter_map { |acima, abaixo| momento_na_rede(acima, abaixo) }.uniq
  end

  # Where the network no longer is what a construção in use was made with
  # (rede editável 2/2a, Q6a), per layer: the momento it kept is not the
  # network's now, its ligação is gone (the trash), or its ligante is no
  # longer one the network allows. Empty when not in use: that one follows
  # the network.
  # Usage: construcao.mudancas_da_rede # => [#<MudancaDaRede posicao=2, texto="guardou dubla antes; a rede agora diz depois", ligacao_uuid="…">]
  def mudancas_da_rede
    return [] unless em_uso?

    camadas_em_ordem.each_cons(2).filter_map { |acima, abaixo| mudanca_na_rede(acima, abaixo) }
  end

  # Dublagem 5a: every ligação dubs before the estampa, so its dublado is
  # made for the stock by an ordem de dublagem.
  def dubla_antes? = momentos_da_dublagem == [ "antes" ]

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

  # Rede editável 1/2 (Q3a, 09/11/2026): a construção not in use follows the
  # network; one in use keeps the momentos it was made with, so a change to
  # the network never moves a pedido already planned.
  def guardar_momentos
    return if em_uso?

    camadas_em_ordem.each_cons(2) { |acima, abaixo| abaixo.dubla = momento_na_rede(acima, abaixo) }
  end

  MudancaDaRede = Struct.new(:posicao, :texto, :ligacao_uuid, keyword_init: true)

  # The link goes to the ligação, or to the one in the trash when it is gone.
  def mudanca_na_rede(acima, abaixo)
    ligacao = acima.ligacao_com(abaixo.materia_prima)
    texto = texto_da_mudanca(ligacao, acima, abaixo)
    return unless texto

    grupos = [ acima, abaixo ].map { |camada| camada.materia_prima.grupo_material }
    MudancaDaRede.new(posicao: abaixo.posicao, texto: texto,
                      ligacao_uuid: ligacao&.uuid || LigacaoDublagem.excluidos.do_par(*grupos).order(deleted_at: :desc).pick(:uuid))
  end

  def texto_da_mudanca(ligacao, acima, abaixo)
    return "a ligação #{acima.materia_prima.grupo_material.nome} e #{abaixo.materia_prima.grupo_material.nome} saiu da rede" unless ligacao
    return "guardou dubla #{abaixo.dubla}; a rede agora diz #{ligacao.dubla}" if ligacao.dubla != abaixo.dubla

    regra = ligacao.ligantes_na(situacao)
    return if abaixo.ligante.nil? || regra.any? { |ligante| ligante.serve?(abaixo.ligante) }

    "o ligante #{abaixo.ligante.nome_completo} não está mais na rede (#{regra.map(&:descricao).join(" ou ")})"
  end

  def momento_na_rede(acima, abaixo)
    acima.ligacao_com(abaixo.materia_prima)&.dubla if acima.materia_prima && abaixo.materia_prima
  end

  def regras_da_rede
    RegrasDaConstrucao.new(self).erros.each { |erro| errors.add(:base, erro) }
  end

  def composicao_fixa_em_uso
    return unless itens_pedido.exists? || MateriaPrima.find(materia_prima_id_in_database).em_uso?
    return unless will_save_change_to_situacao? || will_save_change_to_client_id? || camadas.any? { |camada| camada.new_record? || camada.marked_for_destruction? || camada.changed? }

    errors.add(:base, "#{nome_in_database} já está em uso (estoque ou pedido): só o preço final muda; para outra composição, crie outra construção")
  end
end
