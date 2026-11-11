# What a construção must obey (Dublagem 3/5, decided 30/10-02/11/2026): 2 to
# Parâmetros' maximum of layers (5b1a, Q2d), all tecidos; the first a superfície, the others bases; each pair
# a ligação of the dublagem network, joined by a ligante the network allows
# in the situação — or none while no registered material serves (the cola,
# until 5/5); a client's layer needs the client, and a client needs a layer
# of his; never twice the same construção. Each message names the layer and
# what was expected. A construção in use is not checked against the network
# (rede editável 2/2a, Q6a): its layers can't change, it keeps the momentos
# it was made with, and a change to the network must not stop its final
# price from saving — Construcao#mudancas_da_rede shows what changed.
# Dublagem 5b1a: the chave closes in one dublagem, and none dubs before the
# estampa onto a piece already dubbed after it; the messages name the letter.
#
# Usage: RegrasDaConstrucao.new(construcao).erros # => ["DUB-A, embaixo: Helanca não é base (grupo Helanca)"]
class RegrasDaConstrucao
  # opcoes: where the ligações and registered ligantes come from;
  # construcoes: the ones a new construção must not repeat.
  def initialize(construcao, opcoes: OpcoesDaConstrucao.new(MateriaPrima.all), construcoes: Construcao.all)
    @construcao = construcao
    @opcoes = opcoes
    @construcoes = construcoes
    @chave = construcao.chave
  end

  def erros
    camadas = @construcao.camadas_em_ordem
    maximo = Construcao.maximo_de_camadas
    return [ "a construção tem #{camadas.size} camada(s); esperado de 2 a #{maximo}" ] unless (2..maximo).cover?(camadas.size)

    sem_material = camadas.reject(&:materia_prima)
    return sem_material.map { |camada| "#{@chave.lugar(camada)}: escolha o material" } if sem_material.any?

    erros_da_chave + erros_dos_materiais(camadas) + erros_das_ligacoes + erros_dos_donos(camadas) + erros_de_repeticao(camadas)
  end

  private

  def erros_da_chave
    soltas = @chave.pecas.map(&:nome)
    return [ "a chave não fechou: falta juntar #{soltas.to_sentence(two_words_connector: " e ", last_word_connector: " e ")}" ] unless @chave.fechada?

    @chave.dublagens.select(&:conflito?).map do |dublagem|
      "#{dublagem.letra}: a rede dubla #{grupo(dublagem.acima_da_juncao)} e #{grupo(dublagem.juncao)} antes da estampa, mas #{dublagem.letra_com_superficie.letra} já é depois da Calandra"
    end
  end

  def erros_dos_materiais(camadas)
    camadas.flat_map do |camada|
      material = camada.materia_prima
      next [ "#{@chave.lugar(camada)}: #{material.nome_completo} é #{MateriaPrima::ROTULOS_DOS_TIPOS[material.tipo]}; uma camada é um tecido" ] unless material.tipo == "tecido"

      erros_do_papel(camada, material.grupo_material)
    end
  end

  def erros_do_papel(camada, grupo)
    return [] if camada.superficie? ? grupo.superficie : grupo.base

    [ "#{@chave.lugar(camada)}: #{camada.materia_prima.nome_da_camada} não é #{camada.superficie? ? "superfície" : "base"} (grupo #{grupo.nome})" ]
  end

  # One per dublagem of the chave: its junction's two layers.
  def erros_das_ligacoes
    return [] if @construcao.em_uso?

    @chave.dublagens.flat_map do |dublagem|
      acima = dublagem.acima_da_juncao
      abaixo = dublagem.juncao
      ligacao = @opcoes.ligacao(acima, abaixo.materia_prima)
      next [ "#{dublagem.letra}: #{grupo(acima)} e #{grupo(abaixo)} não dublam — a rede não tem essa ligação" ] unless ligacao

      erros_do_ligante(dublagem, ligacao, "#{grupo(acima)} e #{grupo(abaixo)}")
    end
  end

  def erros_do_ligante(dublagem, ligacao, par)
    camada = dublagem.juncao
    regra = ligacao.ligantes_na(@construcao.situacao).map(&:descricao).to_sentence(two_words_connector: " ou ", last_word_connector: " ou ")
    servem = @opcoes.ligantes(ligacao, @construcao.situacao)
    return [] if camada.ligante ? servem.include?(camada.ligante) : servem.empty?
    return [ "#{dublagem.letra}: escolha o ligante entre #{par} (#{regra})" ] unless camada.ligante

    [ "#{dublagem.letra}: #{camada.ligante.nome_completo} não liga #{par}#{" na situação #{@construcao.situacao_rotulo}" if @construcao.situacao}; a rede pede #{regra}" ]
  end

  def erros_dos_donos(camadas)
    do_cliente = camadas.select(&:do_cliente)
    return do_cliente.map { |camada| "#{@chave.lugar(camada)}: a camada é do cliente; escolha o cliente" } if @construcao.client.nil?
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
