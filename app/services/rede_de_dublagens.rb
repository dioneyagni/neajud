# The dublagem network, from config/dublagens.yml (Dublagem 2/5, decided
# 27-29/10/2026): which groups dub with which, with what ligante, before or
# after the estampa. Read once and checked: a wrong value raises naming it
# and what was expected. Groups are names, never checked against the
# database — a group not registered is a warning (avisos), so a new
# instance or the test database still boots (decision 1).
#
# Usage: RedeDeDublagens.ligacao("Lona", "Oxford").dubla # => "antes"
#        RedeDeDublagens.ligacao("Oxford", "Oxford").ligantes_na("tecido_molha").map(&:descricao) # => ["Filme PU"]
#        RedeDeDublagens.ligacoes_de("Espuma").map { |l| l.outro("Espuma") } # => ["Oxford", "Helanca"]
class RedeDeDublagens
  ARQUIVO = Rails.root.join("config", "dublagens.yml")
  LADOS = %w[trama avesso].freeze
  DUBLA = %w[antes depois].freeze
  A_CONFIRMAR = %w[ligantes dubla situacoes lado].freeze
  ROTULOS_A_CONFIRMAR = { "ligantes" => "ligantes", "dubla" => "antes/depois", "situacoes" => "situações", "lado" => "lado" }.freeze
  CAMPOS = %w[par lado ligantes dubla situacoes a_confirmar].freeze

  class Invalida < StandardError; end

  # A ligante: a group, with the micras it may have — a list, a minimum or
  # any (nil).
  Ligante = Struct.new(:grupo, :micras, :minimo, keyword_init: true) do
    # Usage: ligante.descricao # => "Filme 25 ou 35 µm", "Filme 35 µm ou mais", "Cola"
    def descricao
      return "#{grupo} #{minimo} µm ou mais" if minimo
      return grupo if micras.blank?

      "#{grupo} #{micras.to_sentence(two_words_connector: " ou ", last_word_connector: " ou ")} µm"
    end
  end

  Ligacao = Struct.new(:par, :lado, :ligantes, :dubla, :situacoes, :a_confirmar, keyword_init: true) do
    # The pair in any order (decision 2); a ligação without lado holds for
    # either side.
    def liga?(grupo_a, grupo_b)
      par.map(&:downcase).sort == [ grupo_a, grupo_b ].map { |nome| nome.to_s.downcase }.sort
    end

    # The ligantes in a situação, in place of the usual ones (decision 3);
    # a situação it doesn't list keeps the usual ones.
    def ligantes_na(situacao)
      situacoes.fetch(situacao.to_s, ligantes)
    end

    # The other group of the pair. Usage: ligacao.outro("Lona") # => "Oxford"
    def outro(grupo)
      indice = par.map(&:downcase).index(grupo.to_s.downcase)
      par[1 - indice]
    end

    def a_confirmar?(campo = nil)
      campo ? a_confirmar.include?(campo.to_s) : a_confirmar.any?
    end
  end

  # The ligação of two groups, its lado's one first, else the one for any
  # side; nil when they don't dub.
  def self.ligacao(grupo_a, grupo_b, lado: nil)
    candidatas = ligacoes.select { |ligacao| ligacao.liga?(grupo_a, grupo_b) }
    candidatas.find { |ligacao| lado && ligacao.lado == lado.to_s } || candidatas.find { |ligacao| ligacao.lado.nil? }
  end

  def self.ligacoes_de(grupo)
    ligacoes.select { |ligacao| ligacao.par.map(&:downcase).include?(grupo.to_s.downcase) }
  end

  # What the registered groups contradict, per ligação: a group or ligante
  # not registered, a group that is neither superfície nor base, a pair
  # where neither may go underneath. grupos: the visible GrupoMaterial.
  # Usage: RedeDeDublagens.avisos(ligacao, visiveis(GrupoMaterial)) # => ["Lona — não cadastrado"]
  def self.avisos(ligacao, grupos)
    por_nome = grupos.index_by { |grupo| grupo.nome.downcase }
    faltando = (ligacao.par + todos_os_ligantes(ligacao).map(&:grupo)).uniq.reject { |nome| por_nome[nome.downcase] }
    faltando.map { |nome| "#{nome} — não cadastrado" } + avisos_dos_papeis(ligacao.par.filter_map { |nome| por_nome[nome.downcase] })
  end

  def self.avisos_dos_papeis(grupos)
    sem_papel = grupos.uniq.reject { |grupo| grupo.superficie || grupo.base }.map { |grupo| "#{grupo.nome} não é superfície nem base" }
    sem_base = grupos.size == 2 && grupos.none?(&:base) ? [ "nenhum é base: #{grupos.map(&:nome).uniq.join(" e ")}" ] : []
    sem_papel + sem_base
  end

  def self.todos_os_ligantes(ligacao)
    ligacao.ligantes + ligacao.situacoes.values.flatten
  end

  def self.situacoes
    rede.fetch(:situacoes)
  end

  def self.ligacoes
    rede.fetch(:ligacoes)
  end

  def self.rede
    @rede ||= ler(YAML.safe_load_file(ARQUIVO))
  end

  # Reads and checks a network's content (the YAML as a Hash).
  def self.ler(conteudo)
    situacoes = situacoes_de(conteudo["situacoes"])
    ligacoes = Array(conteudo["ligacoes"]).each_with_index.map { |dados, indice| ligacao_de(dados, indice, situacoes) }
    recusar_repetidas(ligacoes)
    { situacoes: situacoes, ligacoes: ligacoes }
  end

  def self.situacoes_de(dados)
    raise Invalida, "situacoes must be a map of name => label; got #{dados.inspect}" unless dados.is_a?(Hash) && dados.values.all? { |rotulo| rotulo.is_a?(String) && rotulo.present? }

    dados.transform_keys(&:to_s).freeze
  end

  def self.ligacao_de(dados, indice, situacoes)
    raise Invalida, "ligacao #{indice + 1}: must be a map; got #{dados.inspect}" unless dados.is_a?(Hash)

    nome = "ligacao #{indice + 1} (#{Array(dados["par"]).join("–")})"
    erros = erros_da_ligacao(dados, situacoes)
    raise Invalida, "#{nome}: #{erros.join("; ")}" if erros.any?

    Ligacao.new(par: dados["par"].map(&:to_s), lado: dados["lado"], dubla: dados["dubla"], a_confirmar: Array(dados["a_confirmar"]),
                ligantes: dados["ligantes"].map { |ligante| ligante_de(ligante) },
                situacoes: (dados["situacoes"] || {}).to_h { |situacao, ligantes| [ situacao.to_s, ligantes.map { |ligante| ligante_de(ligante) } ] })
  end

  def self.erros_da_ligacao(dados, situacoes)
    (dados.keys - CAMPOS).map { |campo| "unknown field #{campo.inspect}; expected some of #{CAMPOS.join(", ")}" } +
      erros_do_par(dados["par"]) +
      erros_de_valor("lado", dados["lado"], LADOS, opcional: true) + erros_de_valor("dubla", dados["dubla"], DUBLA) +
      erros_dos_ligantes("ligantes", dados["ligantes"]) +
      erros_das_situacoes(dados["situacoes"], situacoes) +
      (Array(dados["a_confirmar"]) - A_CONFIRMAR).map { |campo| "a_confirmar #{campo.inspect} is not one of #{A_CONFIRMAR.join(", ")}" }
  end

  def self.erros_do_par(par)
    return [] if par.is_a?(Array) && par.size == 2 && par.all? { |nome| nome.is_a?(String) && nome.present? }

    [ "par #{par.inspect} must be two group names" ]
  end

  def self.erros_de_valor(campo, valor, validos, opcional: false)
    return [] if validos.include?(valor) || (opcional && valor.nil?)

    [ "#{campo} #{valor.inspect} is not one of #{validos.join(", ")}" ]
  end

  def self.erros_das_situacoes(dados, situacoes)
    return [] if dados.nil?
    return [ "situacoes must be a map of situação => ligantes; got #{dados.inspect}" ] unless dados.is_a?(Hash)

    dados.flat_map do |situacao, ligantes|
      next [ "situação #{situacao.inspect} is not one of #{situacoes.keys.join(", ")}" ] unless situacoes.key?(situacao.to_s)

      erros_dos_ligantes("situação #{situacao}", ligantes)
    end
  end

  def self.erros_dos_ligantes(onde, ligantes)
    return [ "#{onde} must list at least one ligante; got #{ligantes.inspect}" ] unless ligantes.is_a?(Array) && ligantes.any?

    ligantes.flat_map { |ligante| erros_do_ligante(onde, ligante) }
  end

  def self.erros_do_ligante(onde, ligante)
    return [ "#{onde}: a ligante must be { grupo:, micras: }; got #{ligante.inspect}" ] unless ligante.is_a?(Hash) && ligante["grupo"].is_a?(String) && ligante["grupo"].present?
    return [ "#{onde}: unknown ligante field in #{ligante.inspect}; expected grupo, micras" ] if (ligante.keys - %w[grupo micras]).any?

    micras_validas?(ligante["micras"]) ? [] : [ "#{onde}: micras #{ligante["micras"].inspect} must be a list of positive integers or { min: N }" ]
  end

  def self.micras_validas?(micras)
    positivo = ->(valor) { valor.is_a?(Integer) && valor.positive? }
    return true if micras.nil?
    return micras.any? && micras.all?(&positivo) if micras.is_a?(Array)

    micras.is_a?(Hash) && micras.keys == [ "min" ] && positivo.call(micras["min"])
  end

  def self.ligante_de(dados)
    micras = dados["micras"]
    Ligante.new(grupo: dados["grupo"], micras: (micras if micras.is_a?(Array)), minimo: (micras["min"] if micras.is_a?(Hash)))
  end

  # The same pair (any order) and lado twice would make ligacao ambiguous.
  def self.recusar_repetidas(ligacoes)
    iguais = ligacoes.group_by { |ligacao| [ ligacao.par.map(&:downcase).sort, ligacao.lado ] }.values.find { |grupo| grupo.size > 1 }
    return unless iguais

    raise Invalida, "pair #{iguais.last.par.join("–")}#{" (#{iguais.last.lado})" if iguais.last.lado} appears #{iguais.size} times; expected once"
  end
end
