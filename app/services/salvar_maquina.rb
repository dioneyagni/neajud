# Saves a machine from its page (Máquinas 1/5, decided 20/11/2026): the
# name and, per trabalho, whether it does it and at what speed — the Corte
# do calçado its cutting machine's parameters (Q8a, blank = the default). A
# line in its histórico says what changed ("criou com Calandra 40 m/h",
# "acrescentou Dublagem 30 m/h", "tirou Dublagem", "Calandra 40 → 50 m/h",
# "renomeou A → B"); nothing changed, no line.
#
# dados: { nome:, trabalhos: { "calandra" => { marcado: "1", por_hora: "40" },
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
  end

  # "4,5" → "4.5"; blank → nil.
  def numero_digitado(valor)
    valor.to_s.strip.tr(",", ".").presence
  end

  # { nome:, trabalhos: { "calandra" => "Calandra 40 m/h" } }, what the histórico compares.
  def retrato(maquina = @maquina)
    { nome: maquina.nome, trabalhos: maquina.trabalhos_mantidos.to_h { |feito| [ feito.trabalho, feito.descricao ] } }
  end

  def criacao
    "criou com #{@maquina.trabalhos_mantidos.map(&:descricao).to_sentence(words_connector: ", ", two_words_connector: " e ", last_word_connector: " e ")}"
  end

  def mudancas(antes, depois)
    linhas = []
    linhas << "renomeou #{antes[:nome]} → #{depois[:nome]}" if antes[:nome] != depois[:nome]
    linhas += TrabalhosDeMaquina.todos.filter_map { |trabalho| mudanca(trabalho, antes[:trabalhos][trabalho.chave], depois[:trabalhos][trabalho.chave]) }
    linhas.join("; ")
  end

  def mudanca(trabalho, era, ficou)
    return if era == ficou
    return "acrescentou #{ficou}" if era.nil?
    return "tirou #{trabalho.nome}" if ficou.nil?

    "#{era} → #{ficou.delete_prefix(trabalho.nome).strip}"
  end
end
