# The construção as a chave of dublagens (Dublagem 5b1a, decided 10/11/2026;
# canvas "4 · Construção em dublagens"). Each dublagem joins two neighbouring
# pieces of the stack — a material or an earlier dublagem — at the junction
# of the upper piece's bottom layer and the lower piece's top layer, so the
# layers only keep in which dublagem each junction is made
# (camadas_construcao.ordem_da_dublagem). A base layer without it starts a
# piece not joined yet: the chave is still open (only while building). Each
# dublagem sits one column after the latest it uses (Q4a) and is named
# DUB-A, DUB-B… by column, top to bottom.
#
# Usage: chave = ChaveDaConstrucao.new(construcao)
#        chave.dublagens.map(&:letra) # => ["DUB-A", "DUB-B", "DUB-C", "DUB-D"]
#        chave.dublagens.last.momento_real # => "depois"
#        chave.fechada? # => true
class ChaveDaConstrucao
  # One material of the stack; mae is the dublagem it is a side of.
  Folha = Struct.new(:camada, :mae) do
    def camadas = [ camada ]
    def dublagem? = false
    def superficie? = camada.superficie?
    def nome = camada.materia_prima&.nome_da_camada || "material a escolher"
  end

  attr_reader :em_uso

  def initialize(construcao)
    @camadas = construcao.camadas_em_ordem
    @em_uso = construcao.em_uso?
  end

  # The pieces not joined to anything, top to bottom: one when it closed.
  def pecas
    montar unless @pecas
    @pecas
  end

  # Every dublagem by column, top to bottom, each with its letra.
  def dublagens
    montar unless @dublagens
    @dublagens
  end

  def fechada? = pecas.one? && pecas.first.dublagem?

  # The last dublagem, the dublado's own — nil while open.
  def final = (pecas.first if fechada?)

  def colunas = dublagens.map(&:coluna).max || 1

  # Where a layer is in the chave, for a message: "DUB-A, em cima".
  def lugar(camada)
    folha = folhas.find { |candidata| candidata.camada.equal?(camada) }
    mae = folha&.mae
    return "camada #{camada.posicao}" unless mae

    "#{mae.letra}, #{mae.cima.equal?(folha) ? "em cima" : "embaixo"}"
  end

  # The columns a dublagem passes through on its way to the one using it
  # (the canvas's "segue" cards). Usage: chave.segue(dub_a) # => [2]
  def segue(dublagem)
    dublagem.mae ? ((dublagem.coluna + 1)...dublagem.mae.coluna).to_a : []
  end

  # "DUB-A", …, "DUB-Z", "DUB-AA" — the 27th and on.
  def self.letra(indice)
    nome = +""
    numero = indice + 1
    while numero.positive?
      numero, resto = (numero - 1).divmod(26)
      nome.prepend((65 + resto).chr)
    end
    "DUB-#{nome}"
  end

  private

  # The letras are given once every dublagem exists.
  def montar
    @pecas = @camadas.map { |camada| Folha.new(camada) }
    @camadas.filter_map(&:ordem_da_dublagem).uniq.sort.each do |ordem|
      @camadas.select { |camada| camada.ordem_da_dublagem == ordem }.each { |juncao| juntar(@pecas, juncao) }
    end
    @dublagens = @pecas.flat_map { |peca| dentro_de(peca) }.sort_by { |dublagem| [ dublagem.coluna, dublagem.camadas.first.posicao ] }
    @dublagens.each_with_index { |dublagem, indice| dublagem.nomear(indice) }
  end

  def juntar(pecas, juncao)
    indice = pecas.index { |peca| peca.camadas.first.equal?(juncao) }
    pecas[indice - 1, 2] = Dublagem.new(pecas[indice - 1], pecas[indice], self) if indice&.positive?
  end

  def dentro_de(peca)
    peca.dublagem? ? peca.lados.flat_map { |lado| dentro_de(lado) } + [ peca ] : []
  end

  def folhas = pecas.flat_map { |peca| folhas_de(peca) }

  def folhas_de(peca) = peca.dublagem? ? peca.lados.flat_map { |lado| folhas_de(lado) } : [ peca ]

  # One dublagem: cima and baixo, each a Folha or a Dublagem.
  class Dublagem
    attr_reader :cima, :baixo, :letra, :indice
    attr_accessor :mae

    def initialize(cima, baixo, chave)
      @cima = cima
      @baixo = baixo
      @chave = chave
      lados.each { |lado| lado.mae = self }
    end

    def nomear(indice)
      @indice = indice
      @letra = ChaveDaConstrucao.letra(indice)
    end

    def lados = [ cima, baixo ]
    def dublagem? = true
    def nome = letra
    def camadas = cima.camadas + baixo.camadas
    def superficie? = camadas.any?(&:superficie?)
    def letras_usadas = lados.select(&:dublagem?)

    # The piece it ends up in while the chave is open (itself standing alone).
    def raiz = mae ? mae.raiz : self

    # The layer that keeps this dublagem's ligante and momento, and the
    # layer above it.
    def juncao = baixo.camadas.first
    def acima_da_juncao = cima.camadas.last

    def coluna = @coluna ||= 1 + (letras_usadas.map(&:coluna).max || 0)

    # The network's ligação at the junction; nil when a material is missing
    # or the network doesn't have the pair.
    def ligacao
      return unless acima_da_juncao.materia_prima && juncao.materia_prima

      acima_da_juncao.ligacao_com(juncao.materia_prima)
    end

    # The network's antes/depois da estampa — in use, as the layer kept it;
    # a ligação allowing both, the one the card picked ("antes" until then).
    def momento_da_rede
      return juncao.dubla if @chave.em_uso
      return ligacao&.dubla unless ligacao&.escolhe?

      ligacao.permite?(juncao.dubla) ? juncao.dubla : "antes"
    end

    # The card picks antes or depois (Q2a): the ligação allows both, the
    # superfície is in it and nothing forces it.
    def escolhe_momento? = !@chave.em_uso && superficie? && ligacao&.escolhe? && !momento_obrigado?

    # The letra with the superfície it joins already dubs after: so does it.
    # Usage: dub_b.momento_obrigado? # => true ("a DUB-A já é depois")
    def momento_obrigado? = superficie? && ligacao&.permite?("depois") && letra_com_superficie&.momento_real == "depois"

    # Against the Calandra (5b, Q5a): without the superfície it is made
    # before, in parallel with the Impressão; with it, after when its pair
    # dubs after the estampa or the letter with the superfície already did.
    # Usage: dub_d.momento_real # => "depois"
    def momento_real
      return "antes" unless superficie?

      momento_da_rede == "depois" || letra_com_superficie&.momento_real == "depois" ? "depois" : "antes"
    end

    def letra_com_superficie = letras_usadas.find(&:superficie?)

    # A pair dubbed before the estampa onto a piece already dubbed after it.
    # Not when the ligação also allows after (11/11/2026): it follows.
    def conflito? = superficie? && momento_da_rede == "antes" && letra_com_superficie&.momento_real == "depois" && !momento_obrigado?

    # The estampa goes on it: the last dublagem with the superfície before
    # the Calandra.
    def recebe_estampa? = superficie? && momento_real == "antes" && (mae.nil? || mae.momento_real == "depois")
  end
end
