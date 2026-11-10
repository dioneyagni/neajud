# The construção's form read back as layers (Dublagem 5b1a, decided
# 10/11/2026): each card is a dublagem whose cima and baixo are a material
# (its uuid, dono and lado) or an earlier card ("dublagem:<i>", by its place
# in the form — the letter changes with the chave), with its ligante; a card
# standing alone also sends its top layer's posicao, which keeps the loose
# pieces in their order. A card used twice stays with the first; one that
# would end up inside itself stays loose.
#
# acao: "nova" adds an empty card at the end ("+ Par de materiais" and
# "+ Juntar", Q6a); "tirar-<i>-cima|baixo" takes a side out — inside another
# card the card gives way to its other side (without the Napa, DUB-C's place
# is DUB-B's), a card standing alone empties that side and goes away once
# both are empty; a letter taken out goes loose again.
#
# Usage: MontagemDaChave.new(cards, acao: params[:acao], materiais: visiveis(MateriaPrima)).camadas
#        # => [{ materia_prima: oxford, lado: "trama", do_cliente: false, ligante: nil, ordem_da_dublagem: nil }, …]
class MontagemDaChave
  Card = Struct.new(:cima, :baixo, :ligante, :mae, :posicao, keyword_init: true)
  LADOS = %i[cima baixo].freeze

  # cards: the form's cards in order, each a Hash with "cima", "baixo"
  # ("escolha", "do_cliente", "lado"), "ligante_uuid" and "posicao".
  def initialize(cards, acao:, materiais:)
    @dados = cards
    @acao = acao.to_s
    @materiais = materiais
  end

  # The layers top to bottom, as Construcao#definir_camadas takes them.
  def camadas
    cards = ler
    raizes = cards.select { |card| card.mae.nil? }.sort_by.with_index { |card, indice| [ posicao_de(card) || Float::INFINITY, indice ] }
    raizes = aplicar(cards, raizes)
    lista = raizes.flat_map { |raiz| achatar(raiz) }
    lista.first[:lado] = lista.first[:lado].presence || "trama" if lista.any?
    lista
  end

  private

  def ler
    cards = @dados.map { |dados| Card.new(ligante: material(dados["ligante_uuid"]), posicao: dados["posicao"].presence&.to_i) }
    @dados.each_with_index do |dados, indice|
      LADOS.each { |lado| cards[indice][lado] = lado_do_card(dados[lado.to_s] || {}, cards, indice) }
    end
    cards
  end

  # A piece is as high as the highest loose piece it took in: a card that
  # takes the letra on top goes on top.
  def posicao_de(card)
    [ card.posicao, *[ card.cima, card.baixo ].select { |lado| lado.is_a?(Card) }.map { |lado| posicao_de(lado) } ].compact.min
  end

  def lado_do_card(dados, cards, indice)
    escolha = dados["escolha"].to_s
    return folha(material(escolha), dados) unless escolha.start_with?("dublagem:")

    outro = cards[escolha.delete_prefix("dublagem:").to_i]
    return folha(nil, {}) unless outro && outro.mae.nil? && !outro.equal?(cards[indice]) && !dentro?(cards[indice], outro)

    outro.tap { |usado| usado.mae = cards[indice] }
  end

  # Is the card inside the other (the other one of its maes)?
  def dentro?(card, outro)
    mae = card.mae
    mae = mae.mae until mae.nil? || mae.equal?(outro)
    !mae.nil?
  end

  def folha(material, dados)
    { materia_prima: material, do_cliente: dados["do_cliente"] == "1", lado: dados["lado"].presence, ligante: nil, ordem_da_dublagem: nil }
  end

  def material(uuid) = uuid.presence && @materiais.find_by(uuid: uuid)

  def aplicar(cards, raizes)
    return raizes + [ Card.new(cima: folha(nil, {}), baixo: folha(nil, {})) ] if @acao == "nova"

    _, indice, lado = @acao.match(/\Atirar-(\d+)-(cima|baixo)\z/).to_a
    card = cards[indice.to_i] if indice
    card ? tirar(card, lado.to_sym, raizes) : raizes
  end

  # A letra let go keeps its place: above the piece it left when it was on
  # top, below it otherwise.
  def tirar(card, lado, raizes)
    tirado = card[lado]
    raiz = raiz_de(card)
    card.mae ? dar_lugar(card, lado) : card[lado] = folha(nil, {})
    vazio = card.mae.nil? && LADOS.all? { |cada| card[cada].is_a?(Hash) && card[cada][:materia_prima].nil? }
    return (vazio ? raizes - [ card ] : raizes) unless tirado.is_a?(Card)

    tirado.mae = nil
    lugar = raizes.index(raiz) + (lado == :cima ? 0 : 1)
    raizes.dup.insert(lugar, tirado).then { |lista| vazio ? lista - [ card ] : lista }
  end

  def raiz_de(card) = card.mae ? raiz_de(card.mae) : card

  # Inside another card: the other side takes the card's place.
  def dar_lugar(card, lado)
    outro = card[lado == :cima ? :baixo : :cima]
    mae = card.mae
    mae[mae.cima.equal?(card) ? :cima : :baixo] = outro
    outro.mae = mae if outro.is_a?(Card)
  end

  def achatar(no)
    return [ no.dup ] if no.is_a?(Hash)

    cima = achatar(no.cima)
    baixo = achatar(no.baixo)
    baixo[0] = baixo[0].merge(ligante: no.ligante, ordem_da_dublagem: coluna(no))
    cima + baixo
  end

  def coluna(no) = 1 + ([ no.cima, no.baixo ].select { |lado| lado.is_a?(Card) }.map { |lado| coluna(lado) }.max || 0)
end
