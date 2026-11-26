# The map of the system (Primeiros passos 1/6, decided 26/11/2026, Q8a):
# config/mapa.yml read once — each part with its block, page, what it needs
# before it can start and what it feeds, who fills it on a new instance and
# its empty screen. The empty screens (shared/_estado_vazio), and later the
# wizard, the example and the tours, all come from here.
#
# A link to a part that doesn't exist, a page with no route, an action of
# an unknown kind or a contagem with no counter raises, naming it.
#
# Usage: MapaDoSistema.parte(:pedido).vazio.titulo # => "Nenhum pedido ainda"
#        MapaDoSistema.falta(:pedido, visiveis: ->(m) { m.all }).map(&:texto) # => ["3 cadastrados", "nenhuma ainda", …]
class MapaDoSistema
  class Invalido < StandardError; end

  ARQUIVO = Rails.root.join("config/mapa.yml")
  PREENCHE = %w[vem assistente pessoa sistema].freeze
  TIPOS_DE_ACAO = %w[link post dialogo ancora].freeze

  Bloco = Struct.new(:id, :nome, :cor, keyword_init: true)
  Parte = Struct.new(:id, :nome, :bloco, :pagina, :icone, :precisa, :alimenta, :preenche, :vazio, keyword_init: true)
  Vazio = Struct.new(:titulo, :texto, :acao, :falta, :depois, keyword_init: true)
  Acao = Struct.new(:rotulo, :tipo, :alvo, :permissao, keyword_init: true)
  Contagem = Struct.new(:id, :parte, :rotulo, :nenhum, :algum, keyword_init: true)
  # ok: it exists (ritmos: every stage has one); texto: "3 cadastrados".
  Falta = Struct.new(:contagem, :parte, :ok, :texto, keyword_init: true)

  # What each contagem counts, through the scope the person sees
  # (visiveis: a callable, the controller's visiveis). An Integer, or
  # [done, total] for one that must be complete.
  CONTADORES = {
    "clientes" => ->(v) { v.call(Client).ativos.count },
    "artes" => ->(v) { v.call(Arte).where(id: v.call(Arquivo).ativos.where(category: "artes").select(:arte_id)).count },
    "moldes" => ->(v) { v.call(Molde).ativos.count },
    "materiais" => ->(v) { v.call(MateriaPrima).count },
    "turnos" => ->(v) { v.call(Turno).ativos.count },
    "ritmos" => lambda { |v|
      ritmos = RitmoProducao.da_fabrica(v.call(RitmoProducao).to_a, trabalhos: v.call(TrabalhoDaMaquina).ativos).values
      [ ritmos.count { |ritmo| ritmo.maquina_de_corte? || ritmo.informado }, ritmos.size ]
    },
    "pedidos_confirmados" => ->(v) { v.call(Pedido).ativos.where(status: Pedido::EM_PRODUCAO).count }
  }.freeze

  class << self
    def blocos = carregado[:blocos]
    def partes = carregado[:partes]
    def contagens = carregado[:contagens]

    # Usage: MapaDoSistema.parte(:cliente).nome # => "Clientes"
    def parte(id)
      partes.fetch(id.to_s) { raise Invalido, "unknown part #{id.inspect} of the map; expected one of #{partes.keys.join(", ")}" }
    end

    # Its empty screen's "what comes before", counted for who sees it.
    def falta(id, visiveis:)
      Array(parte(id).vazio&.falta).map { |chave| contar(contagens.fetch(chave), visiveis) }
    end

    # Forgets what was read (a spec that writes its own map).
    def recarregar!
      @carregado = nil
    end

    private

    def carregado
      @carregado ||= LeitorDoMapa.new(YAML.safe_load_file(ARQUIVO)).call
    end

    def contar(contagem, visiveis)
      n, total = CONTADORES.fetch(contagem.id).call(visiveis)
      ok = n.positive? && (total.nil? || n >= total)
      texto = n.zero? ? contagem.nenhum : format(contagem.algum, n: n, total: total)
      Falta.new(contagem: contagem, parte: parte(contagem.parte), ok: ok, texto: texto)
    end
  end
end
