# Reads and checks db/seeds/rede_de_dublagens.yml (Dublagem 2/5; moved out
# of RedeDeDublagens when the network went to the database, rede editável
# 1/2, 09/11/2026): a wrong value raises ImportarRedeDeDublagens::Invalida
# naming the ligação, the value and what was expected.
#
# Usage: LeituraDaRedeInicial.new(YAML.safe_load_file(arquivo)).call
#        # => { grupos: { "Oxford" => { "superficie" => true, … } }, situacoes: { "tecido_molha" => "Tecido molha" }, ligacoes: [RedeDeDublagens::Ligacao, …] }
class LeituraDaRedeInicial
  CAMPOS = %w[par lado ligantes dubla situacoes a_confirmar].freeze
  PAPEIS = %w[superficie base estampavel].freeze

  def initialize(conteudo)
    @conteudo = conteudo
  end

  def call
    raise ImportarRedeDeDublagens::Invalida, "the network must be a map with grupos, situacoes and ligacoes; got #{@conteudo.class}" unless @conteudo.is_a?(Hash)

    situacoes = situacoes_de(@conteudo["situacoes"])
    ligacoes = Array(@conteudo["ligacoes"]).each_with_index.map { |dados, indice| ligacao_de(dados, indice, situacoes) }
    recusar_repetidas(ligacoes)
    { grupos: grupos_de(@conteudo["grupos"]), situacoes: situacoes, ligacoes: ligacoes }
  end

  private

  def grupos_de(dados)
    return {} if dados.nil?
    raise ImportarRedeDeDublagens::Invalida, "grupos must be a map of name => roles; got #{dados.inspect}" unless dados.is_a?(Hash)

    dados.each { |nome, papeis| recusar_papeis(nome, papeis) }
  end

  def recusar_papeis(nome, papeis)
    return if papeis.is_a?(Hash) && papeis.keys.sort == PAPEIS.sort && [ papeis["superficie"], papeis["base"] ].all? { |valor| [ true, false ].include?(valor) } &&
              GrupoMaterial::ESTAMPAVEL.include?(papeis["estampavel"])

    raise ImportarRedeDeDublagens::Invalida, "grupo #{nome}: roles #{papeis.inspect}; expected { superficie: true|false, base: true|false, estampavel: #{GrupoMaterial::ESTAMPAVEL.join("|")} }"
  end

  def situacoes_de(dados)
    raise ImportarRedeDeDublagens::Invalida, "situacoes must be a map of name => label; got #{dados.inspect}" unless dados.is_a?(Hash) && dados.values.all? { |rotulo| rotulo.is_a?(String) && rotulo.present? }

    dados.transform_keys(&:to_s).freeze
  end

  def ligacao_de(dados, indice, situacoes)
    raise ImportarRedeDeDublagens::Invalida, "ligacao #{indice + 1}: must be a map; got #{dados.inspect}" unless dados.is_a?(Hash)

    nome = "ligacao #{indice + 1} (#{Array(dados["par"]).join("–")})"
    erros = erros_da_ligacao(dados, situacoes)
    raise ImportarRedeDeDublagens::Invalida, "#{nome}: #{erros.join("; ")}" if erros.any?

    RedeDeDublagens::Ligacao.new(par: dados["par"].map(&:to_s), lado: dados["lado"], dubla: dados["dubla"], a_confirmar: Array(dados["a_confirmar"]),
                                 ligantes: dados["ligantes"].map { |ligante| ligante_de(ligante) },
                                 situacoes: (dados["situacoes"] || {}).to_h { |situacao, ligantes| [ situacao.to_s, ligantes.map { |ligante| ligante_de(ligante) } ] })
  end

  def erros_da_ligacao(dados, situacoes)
    (dados.keys - CAMPOS).map { |campo| "unknown field #{campo.inspect}; expected some of #{CAMPOS.join(", ")}" } +
      erros_do_par(dados["par"]) +
      erros_de_valor("lado", dados["lado"], RedeDeDublagens::LADOS, opcional: true) + erros_de_valor("dubla", dados["dubla"], RedeDeDublagens::DUBLA_DA_LIGACAO) +
      erros_dos_ligantes("ligantes", dados["ligantes"]) +
      erros_das_situacoes(dados["situacoes"], situacoes) +
      (Array(dados["a_confirmar"]) - RedeDeDublagens::A_CONFIRMAR).map { |campo| "a_confirmar #{campo.inspect} is not one of #{RedeDeDublagens::A_CONFIRMAR.join(", ")}" }
  end

  def erros_do_par(par)
    return [] if par.is_a?(Array) && par.size == 2 && par.all? { |nome| nome.is_a?(String) && nome.present? }

    [ "par #{par.inspect} must be two group names" ]
  end

  def erros_de_valor(campo, valor, validos, opcional: false)
    return [] if validos.include?(valor) || (opcional && valor.nil?)

    [ "#{campo} #{valor.inspect} is not one of #{validos.join(", ")}" ]
  end

  def erros_das_situacoes(dados, situacoes)
    return [] if dados.nil?
    return [ "situacoes must be a map of situação => ligantes; got #{dados.inspect}" ] unless dados.is_a?(Hash)

    dados.flat_map do |situacao, ligantes|
      next [ "situação #{situacao.inspect} is not one of #{situacoes.keys.join(", ")}" ] unless situacoes.key?(situacao.to_s)

      erros_dos_ligantes("situação #{situacao}", ligantes)
    end
  end

  def erros_dos_ligantes(onde, ligantes)
    return [ "#{onde} must list at least one ligante; got #{ligantes.inspect}" ] unless ligantes.is_a?(Array) && ligantes.any?

    ligantes.flat_map { |ligante| erros_do_ligante(onde, ligante) }
  end

  def erros_do_ligante(onde, ligante)
    return [ "#{onde}: a ligante must be { grupo:, micras: }; got #{ligante.inspect}" ] unless ligante.is_a?(Hash) && ligante["grupo"].is_a?(String) && ligante["grupo"].present?
    return [ "#{onde}: unknown ligante field in #{ligante.inspect}; expected grupo, micras" ] if (ligante.keys - %w[grupo micras]).any?

    micras_validas?(ligante["micras"]) ? [] : [ "#{onde}: micras #{ligante["micras"].inspect} must be a list of positive integers or { min: N }" ]
  end

  def micras_validas?(micras)
    positivo = ->(valor) { valor.is_a?(Integer) && valor.positive? }
    return true if micras.nil?
    return micras.any? && micras.all?(&positivo) if micras.is_a?(Array)

    micras.is_a?(Hash) && micras.keys == [ "min" ] && positivo.call(micras["min"])
  end

  def ligante_de(dados)
    micras = dados["micras"]
    RedeDeDublagens::Ligante.new(grupo: dados["grupo"], micras: (micras if micras.is_a?(Array)), minimo: (micras["min"] if micras.is_a?(Hash)))
  end

  # The same pair (any order) and lado twice would make ligacao ambiguous.
  def recusar_repetidas(ligacoes)
    iguais = ligacoes.group_by { |ligacao| [ ligacao.par.map(&:downcase).sort, ligacao.lado ] }.values.find { |grupo| grupo.size > 1 }
    return unless iguais

    raise ImportarRedeDeDublagens::Invalida, "pair #{iguais.last.par.join("–")}#{" (#{iguais.last.lado})" if iguais.last.lado} appears #{iguais.size} times; expected once"
  end
end
