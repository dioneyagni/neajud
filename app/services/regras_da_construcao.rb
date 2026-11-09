# What a construção must obey (Dublagem 3/5, decided 30/10-02/11/2026): 2 to
# 5 layers, all tecidos; the first a superfície, the others bases; each pair
# a ligação of the dublagem network, joined by a ligante the network allows
# in the situação — or none while no registered material serves (the cola,
# until 5/5); a client's layer needs the client, and a client needs a layer
# of his; never twice the same construção. Each message names the layer and
# what was expected.
#
# Usage: RegrasDaConstrucao.new(construcao).erros # => ["camada 2: Helanca não é base (grupo Helanca)"]
class RegrasDaConstrucao
  # opcoes: where the ligações and registered ligantes come from;
  # construcoes: the ones a new construção must not repeat.
  def initialize(construcao, opcoes: OpcoesDaConstrucao.new(MateriaPrima.all), construcoes: Construcao.all)
    @construcao = construcao
    @opcoes = opcoes
    @construcoes = construcoes
  end

  def erros
    camadas = @construcao.camadas_em_ordem
    return [ "a construção tem #{camadas.size} camada(s); esperado de 2 a #{Construcao::MAXIMO_DE_CAMADAS}" ] unless (2..Construcao::MAXIMO_DE_CAMADAS).cover?(camadas.size)

    sem_material = camadas.reject(&:materia_prima)
    return sem_material.map { |camada| "camada #{camada.posicao}: escolha o material" } if sem_material.any?

    erros_dos_materiais(camadas) + erros_das_ligacoes(camadas) + erros_dos_donos(camadas) + erros_de_repeticao(camadas)
  end

  private

  def erros_dos_materiais(camadas)
    camadas.flat_map do |camada|
      material = camada.materia_prima
      next [ "camada #{camada.posicao}: #{material.nome_completo} é #{MateriaPrima::ROTULOS_DOS_TIPOS[material.tipo]}; uma camada é um tecido" ] unless material.tipo == "tecido"

      erros_do_papel(camada, material.grupo_material)
    end
  end

  def erros_do_papel(camada, grupo)
    return [] if camada.superficie? ? grupo.superficie : grupo.base

    [ "camada #{camada.posicao}: #{camada.materia_prima.nome_da_camada} não é #{camada.superficie? ? "superfície" : "base"} (grupo #{grupo.nome})" ]
  end

  def erros_das_ligacoes(camadas)
    camadas.each_cons(2).flat_map do |acima, abaixo|
      ligacao = @opcoes.ligacao(acima, abaixo.materia_prima)
      next [ "camada #{abaixo.posicao}: #{grupo(acima)} e #{grupo(abaixo)} não dublam — a rede não tem essa ligação" ] unless ligacao

      erros_do_ligante(abaixo, ligacao, "#{grupo(acima)} e #{grupo(abaixo)}")
    end
  end

  def erros_do_ligante(camada, ligacao, par)
    regra = ligacao.ligantes_na(@construcao.situacao).map(&:descricao).to_sentence(two_words_connector: " ou ", last_word_connector: " ou ")
    servem = @opcoes.ligantes(ligacao, @construcao.situacao)
    return [] if camada.ligante ? servem.include?(camada.ligante) : servem.empty?
    return [ "camada #{camada.posicao}: escolha o ligante entre #{par} (#{regra})" ] unless camada.ligante

    [ "camada #{camada.posicao}: #{camada.ligante.nome_completo} não liga #{par}#{" na situação #{@construcao.situacao_rotulo}" if @construcao.situacao}; a rede pede #{regra}" ]
  end

  def erros_dos_donos(camadas)
    do_cliente = camadas.select(&:do_cliente)
    return do_cliente.map { |camada| "camada #{camada.posicao} é do cliente: escolha o cliente" } if @construcao.client.nil?
    return [] if do_cliente.any?

    [ "#{@construcao.client.name} não tem camada nesta construção: marque a camada dele ou tire o cliente" ]
  end

  def erros_de_repeticao(camadas)
    identidade = camadas.map(&:identidade)
    candidatas = @construcoes.where(client_id: @construcao.client_id, situacao: @construcao.situacao).where.not(id: @construcao.id).includes(:camadas)
    igual = candidatas.find { |outra| outra.camadas.map(&:identidade) == identidade }
    return [] unless igual
    return [ igual.aviso_na_lixeira ] if igual.excluido?

    [ "igual a \"#{igual.nome}\", que já existe" ]
  end

  def grupo(camada) = camada.materia_prima.grupo_material.nome
end
