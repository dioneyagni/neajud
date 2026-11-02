# A construção's suggested price per meter (Dublagem 3/5; plano Etapa 2.9
# D7): the empresa's layers at their price per meter — the client's stay out
# —, each ligação's ligante at its price per meter and the empresa's service
# value per ligação. A price not set is a line marked "sem preço" that adds
# nothing, so the panel says what is missing instead of a wrong total.
#
# Usage: preco = PrecoSugeridoDaConstrucao.new(construcao, servico: Empresa.atual.preco_servico_dublagem)
#        preco.linhas.map(&:rotulo) # => ["Oxford-Preto-1.40 m-100g", "Lona-Branco-1.40 m", "Filme 35 µm-…", "Serviço × 1 ligação"]
#        preco.total # => 31.5
class PrecoSugeridoDaConstrucao
  SEM_PRECO = "sem preço".freeze

  Linha = Struct.new(:rotulo, :valor, :nota, keyword_init: true)

  # servico: the empresa's value per ligação (nil = not set).
  def initialize(construcao, servico:)
    @construcao = construcao
    @servico = servico
  end

  def linhas
    @linhas ||= begin
      camadas = @construcao.camadas_em_ordem.select(&:materia_prima)
      camadas.map { |camada| linha_da_camada(camada) } + camadas.drop(1).map { |camada| linha_do_ligante(camada) } + [ linha_do_servico ].compact
    end
  end

  def total = linhas.sum { |linha| linha.valor || 0 }

  # The lines that should have a price and don't.
  def sem_preco = linhas.select { |linha| linha.nota == SEM_PRECO }

  private

  def linha_da_camada(camada)
    material = camada.materia_prima
    return Linha.new(rotulo: material.nome_completo, nota: "do cliente") if camada.do_cliente

    linha_com_preco(material.nome_completo, material.preco_metro)
  end

  def linha_do_ligante(camada)
    ligacao = "ligação #{camada.posicao - 1}"
    # Not chosen yet, or none registered serves (the cola, until 5/5): the
    # layer's ligação says which.
    return Linha.new(rotulo: "Ligante da #{ligacao}", nota: "sem ligante") unless camada.ligante

    linha_com_preco("#{camada.ligante.nome_completo} (#{ligacao})", camada.ligante.preco_metro)
  end

  def linha_do_servico
    quantas = @construcao.ligacoes
    return if quantas.zero?

    linha_com_preco("Serviço × #{quantas} #{quantas == 1 ? "ligação" : "ligações"}", @servico && @servico * quantas)
  end

  def linha_com_preco(rotulo, valor)
    valor ? Linha.new(rotulo: rotulo, valor: valor) : Linha.new(rotulo: rotulo, nota: SEM_PRECO)
  end
end
