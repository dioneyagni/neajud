# Saves a machine from its page (Máquinas 1/5, decided 20/11/2026): the
# name and, per trabalho, whether it does it and at what speed — the Corte
# do calçado its cutting machine's parameters (Q8a, blank = the default). A
# line in its histórico says what changed ("criou com Calandra 40 m/h",
# "acrescentou Dublagem 30 m/h", "tirou Dublagem", "Calandra 40 → 50 m/h",
# "renomeou A → B"); nothing changed, no line.
#
# Máquinas 4/5b (Q4a): "usar a informada", the fix of each trabalho, read
# only when sent (the page sends it for the trabalhos it shows); its line
# says "Calandra: passou a usar a informada" / "voltou a usar a medida".
#
# dados: { nome:, trabalhos: { "calandra" => { marcado: "1", por_hora: "40", fixar_informado: "1" },
#          "corte_calcado" => { marcado: "1", velocidade_mm_s: "120", … } } } (numbers as typed: "4,5")
#
# Usage: SalvarMaquina.new(maquina, dados, user: Current.user).call # => true, or false with maquina.errors
class SalvarMaquina
  CAMPOS = [ :por_hora, *ParametrosDoCorte::PADRAO.keys ].freeze

  def initialize(maquina, dados, user:)
    @maquina = maquina
    @dados = dados.to_h.with_indifferent_access
    @user = user
  end

  def call
    antes = retrato unless @maquina.new_record?
    aplicar
    return false unless @maquina.valid?

    Maquina.transaction do
      @maquina.save!
      texto = antes ? mudancas(antes, retrato(@maquina.reload)) : criacao
      @maquina.alteracoes.create!(texto: texto, user: @user) if texto.present?
    end
    true
  end

  private

  def aplicar
    @maquina.nome = @dados[:nome].to_s.squish
    TrabalhosDeMaquina.todos.each { |trabalho| aplicar_trabalho(trabalho, @dados.dig(:trabalhos, trabalho.chave) || {}) }
  end

  def aplicar_trabalho(trabalho, linha)
    existente = @maquina.trabalhos.find { |feito| feito.trabalho == trabalho.chave }
    return existente&.mark_for_destruction unless linha[:marcado] == "1"

    feito = existente || @maquina.trabalhos.build(trabalho: trabalho.chave)
    feito.assign_attributes(CAMPOS.index_with { |campo| numero_digitado(linha[campo]) })
    feito.por_hora = nil if feito.corte_por_parametros?
    feito.fixar_informado = linha[:fixar_informado] == "1" if linha.key?(:fixar_informado)
  end

  # "4,5" → "4.5"; blank → nil.
  def numero_digitado(valor)
    valor.to_s.strip.tr(",", ".").presence
  end

  # { nome:, trabalhos: { "calandra" => "Calandra 40 m/h" }, fixados: { "calandra" => true } }, what the histórico compares.
  def retrato(maquina = @maquina)
    mantidos = maquina.trabalhos_mantidos
    { nome: maquina.nome, trabalhos: mantidos.to_h { |feito| [ feito.trabalho, feito.descricao ] }, fixados: mantidos.to_h { |feito| [ feito.trabalho, feito.fixar_informado ] } }
  end

  def criacao
    "criou com #{@maquina.trabalhos_mantidos.map(&:descricao).to_sentence(words_connector: ", ", two_words_connector: " e ", last_word_connector: " e ")}"
  end

  def mudancas(antes, depois)
    linhas = []
    linhas << "renomeou #{antes[:nome]} → #{depois[:nome]}" if antes[:nome] != depois[:nome]
    linhas += TrabalhosDeMaquina.todos.filter_map { |trabalho| mudanca(trabalho, antes[:trabalhos][trabalho.chave], depois[:trabalhos][trabalho.chave]) }
    linhas += TrabalhosDeMaquina.todos.filter_map { |trabalho| mudanca_do_fix(trabalho, antes[:fixados][trabalho.chave], depois[:fixados][trabalho.chave]) }
    linhas.join("; ")
  end

  # Only a trabalho it kept: a new one starts unfixed, a removed one says "tirou".
  def mudanca_do_fix(trabalho, era, ficou)
    return if era.nil? || ficou.nil? || era == ficou

    "#{trabalho.nome}: #{ficou ? "passou a usar a informada" : "voltou a usar a medida"}"
  end

  def mudanca(trabalho, era, ficou)
    return if era == ficou
    return "acrescentou #{ficou}" if era.nil?
    return "tirou #{trabalho.nome}" if ficou.nil?

    "#{era} → #{ficou.delete_prefix(trabalho.nome).strip}"
  end
end
