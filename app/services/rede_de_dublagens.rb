# The dublagem network (Dublagem 2/5, decided 27-29/10/2026): which groups
# dub with which, with what ligante, before or after the estampa. In the
# database since rede editável 1/2 (09/11/2026, Q1a): LigacaoDublagem,
# LiganteDaLigacao and SituacaoDublagem, read here once per request or job
# (Current) and forgotten when they change. The initial one comes from
# db/seeds/rede_de_dublagens.yml (ImportarRedeDeDublagens).
#
# Usage: RedeDeDublagens.ligacao("Lona", "Oxford").dubla # => "antes"
#        RedeDeDublagens.ligacao("Oxford", "Oxford").ligantes_na("tecido_molha").map(&:descricao) # => ["Filme PU"]
#        RedeDeDublagens.ligacoes_de("Espuma").map { |l| l.outro("Espuma") } # => ["Oxford", "Helanca"]
#        RedeDeDublagens.new(ligacoes: visiveis(LigacaoDublagem), situacoes: visiveis(SituacaoDublagem)).ligacoes
class RedeDeDublagens
  LADOS = %w[trama avesso].freeze
  DUBLA = %w[antes depois].freeze
  A_CONFIRMAR = %w[ligantes dubla situacoes lado].freeze
  ROTULOS_A_CONFIRMAR = { "ligantes" => "ligantes", "dubla" => "antes/depois", "situacoes" => "situações", "lado" => "lado" }.freeze

  # A ligante: a group, with the micras it may have — a list, a minimum or
  # any (nil).
  Ligante = Struct.new(:grupo, :micras, :minimo, keyword_init: true) do
    # Usage: ligante.descricao # => "Filme 25 ou 35 µm", "Filme 35 µm ou mais", "Cola"
    def descricao
      return "#{grupo} #{minimo} µm ou mais" if minimo
      return grupo if micras.blank?

      "#{grupo} #{micras.to_sentence(two_words_connector: " ou ", last_word_connector: " ou ")} µm"
    end

    # Whether a registered material is this ligante: its group, with micras in
    # the list or at least the minimum (Dublagem 3/5).
    # Usage: ligante.serve?(filme_35) # => true
    def serve?(material)
      return false unless material.grupo_material.nome.casecmp?(grupo)
      return material.micras.to_i >= minimo if minimo

      micras.blank? || micras.include?(material.micras)
    end
  end

  # grupos: the pair's GrupoMaterial, in the par's order; uuid: the
  # LigacaoDublagem's (nil when read from the initial file).
  Ligacao = Struct.new(:uuid, :par, :grupos, :lado, :ligantes, :dubla, :situacoes, :a_confirmar, keyword_init: true) do
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

  # The network of this request or job, read once.
  def self.atual = Current.rede_de_dublagens ||= new

  # Called when a ligação, ligante or situação changes, so the next read
  # sees it.
  def self.esquecer
    Current.rede_de_dublagens = nil
  end

  class << self
    delegate :ligacao, :ligacoes_de, :ligacoes, :situacoes, to: :atual
  end

  # What the groups' roles contradict, per ligação: a group that is neither
  # superfície nor base, a pair where neither may go underneath.
  # Usage: RedeDeDublagens.avisos(ligacao) # => ["Lona não é superfície nem base"]
  def self.avisos(ligacao)
    grupos = ligacao.grupos
    sem_papel = grupos.uniq.reject { |grupo| grupo.superficie || grupo.base }.map { |grupo| "#{grupo.nome} não é superfície nem base" }
    sem_base = grupos.none?(&:base) ? [ "nenhum é base: #{grupos.map(&:nome).uniq.join(" e ")}" ] : []
    sem_papel + sem_base
  end

  # ligacoes, situacoes: the scopes to read (the visible ones in a controller);
  # a ligação in the trash is never read (rede editável 2/2a).
  def initialize(ligacoes: LigacaoDublagem.all, situacoes: SituacaoDublagem.all)
    @escopo_das_ligacoes = ligacoes
    @escopo_das_situacoes = situacoes
  end

  # The ligação of two groups (by name), its lado's one first, else the one
  # for any side; nil when they don't dub.
  def ligacao(grupo_a, grupo_b, lado: nil)
    candidatas = ligacoes.select { |ligacao| ligacao.liga?(grupo_a, grupo_b) }
    candidatas.find { |ligacao| lado && ligacao.lado == lado.to_s } || candidatas.find { |ligacao| ligacao.lado.nil? }
  end

  def ligacoes_de(grupo)
    ligacoes.select { |ligacao| ligacao.par.map(&:downcase).include?(grupo.to_s.downcase) }
  end

  # Usage: rede.situacoes # => { "vai_frequencia" => "Vai frequência", "tecido_molha" => "Tecido molha" }
  def situacoes
    @situacoes ||= @escopo_das_situacoes.order(:id).to_h { |situacao| [ situacao.chave, situacao.nome ] }.freeze
  end

  # In the order they were added.
  def ligacoes
    @ligacoes ||= @escopo_das_ligacoes.ativos.includes(:grupo_a, :grupo_b, ligantes: %i[grupo_material situacao_dublagem]).order(:id).map(&:para_rede).freeze
  end
end
