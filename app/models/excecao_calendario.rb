# A day — or one turno of it — the factory, or one stage, doesn't work
# (Painel 2/4a, decided 05/11/2026, Q8a): a holiday, a recess, the Calandra
# stopped for maintenance. The previsão (2/4b) skips it: the stage has no
# capacity there. A national holiday the dono confirms is one too, with
# origem "feriado" (FeriadosNacionais suggests them, Q9a).
#
# Removed physically, like a molde's price: it is a setting about the
# future, and the baixas already given keep their own times — a stop made
# by mistake. One that happened stays, with "voltou a funcionar".
#
# Máquinas 3/5a (decided 24/11/2026): it runs from data to data_fim (Q6a,
# the turno on each day); it may take some of its stage's machines (Q1a:
# each whole, in every stage it does — the Calandra 2 stops its Dublagem
# too), none = the whole stage as before; it keeps who made it, what it did
# to the queue when saved (`impacto`, ImpactoDaParada — Q4a, for the
# bulletins to come) and when it came back to work and who said so (Q7a).
#
# Usage: ExcecaoCalendario.create!(data: Date.new(2026, 11, 13), nome: "Calandra parada", etapa: "calandra")
#        excecao.parada_ate(ocorrencia, "calandra") # => the turno's end: it stops all of it
class ExcecaoCalendario < ApplicationRecord
  include GeraUuid
  include AvisaAFila

  self.table_name = "excecoes_calendario"

  ORIGENS = %w[manual feriado].freeze

  belongs_to :turno, optional: true
  belongs_to :user, optional: true
  belongs_to :voltou_por, class_name: "User", optional: true
  has_many :paradas_das_maquinas, class_name: "ParadaDaMaquina", inverse_of: :excecao_calendario, dependent: :destroy
  has_many :maquinas, through: :paradas_das_maquinas
  atribui_por_uuid :turno

  before_validation { self.data_fim ||= data }

  validates :data, presence: true
  validates :nome, presence: true
  validates :origem, inclusion: { in: ORIGENS }
  validates :data, uniqueness: { conditions: -> { where(origem: "feriado") }, message: "already has its national holiday" }, if: -> { origem == "feriado" }
  validate :etapa_conhecida
  validate :periodo_em_ordem
  validate :maquinas_da_etapa

  # The ones touching the year (a stop from December into January in both).
  scope :do_ano, ->(ano) { where(data: ..Date.new(ano, 12, 31)).where(data_fim: Date.new(ano, 1, 1)..) }

  # Every stage key of config/etapas_producao.yml, with its name; a stage
  # in another's sector stops with it (5b1c2, Q2a: one dublagem machine), so
  # the Dublagem final is not offered and the Dublagem says it stops both.
  # Usage: ExcecaoCalendario.etapas # => { "impressao" => "Impressão", "dublagem" => "Dublagem (as duas etapas)", … }
  def self.etapas
    etapas = EtapasProducao.todas.values.flatten.reject { |etapa| LinhaDoPainel::SETOR_DA_ETAPA.key?(etapa.chave) }
    etapas.to_h { |etapa| [ etapa.chave, LinhaDoPainel::SETOR_DA_ETAPA.value?(etapa.chave) ? "#{etapa.nome} (as duas etapas)" : etapa.nome ] }
  end

  def da_fabrica?
    etapa.nil?
  end

  # Until when it stops this occurrence (CalendarioDeProducao::Ocorrencia)
  # for the stage — nil etapa asks about the whole factory — or its machine:
  # the turno's end, the moment it came back to work, or nil when it doesn't
  # stop it. A stop of machines takes only them, in any stage (Q1a); one of
  # a stage, all of its machines. The Dublagem's stops the Dublagem final
  # too, its sector's (5b1c2).
  # Usage: excecao.parada_ate(ocorrencia, "calandra", maquina_id: calandra_2.id) # => ocorrencia.fim
  def parada_ate(ocorrencia, chave_da_etapa = nil, maquina_id: nil)
    return unless no_periodo?(ocorrencia) && para_quem?(chave_da_etapa, maquina_id)
    return ocorrencia.fim unless voltou_em
    return if voltou_em <= ocorrencia.inicio

    [ voltou_em, ocorrencia.fim ].min
  end

  # Under way: started, not ended (what "voltou a funcionar" ends).
  def em_andamento?(hoje = Date.current)
    data <= hoje && !encerrada?(hoje)
  end

  # Has it ended — the last day gone, or it came back to work?
  def encerrada?(hoje = Date.current)
    voltou_em.present? || (data_fim || data) < hoje
  end

  # Usage: excecao.abrangencia # => "Calandra › Calandra 2 · Tarde" / "Impressão › todas as máquinas · dia inteiro" / "toda a fábrica · dia inteiro"
  def abrangencia
    [ quem_para, turno ? turno.nome : "dia inteiro" ].join(" · ")
  end

  # The trabalhos doing the stage (TrabalhosDeMaquina), any tipo's: the
  # Impressão is the paper's and the DTF's.
  # Usage: ExcecaoCalendario.trabalhos_da_etapa("impressao") # => ["impressao_papel", "impressao_dtf"]
  def self.trabalhos_da_etapa(etapa)
    TrabalhosDeMaquina.todos.select { |trabalho| trabalho.etapas.any? { |_, chave| chave == etapa.to_s } }.map(&:chave)
  end

  # The other stages its machines stop in (Q1a: "para também na Dublagem").
  # Usage: excecao.tambem_para # => ["Dublagem"]
  def tambem_para
    proprios = self.class.trabalhos_da_etapa(etapa)
    paradas_das_maquinas.map(&:maquina).flat_map(&:trabalhos).map(&:trabalho).uniq.reject { |chave| proprios.include?(chave) }.map { |chave| TrabalhosDeMaquina.trabalho(chave).nome }
  end

  private

  def quem_para
    return "toda a fábrica" if da_fabrica?

    nome = self.class.etapas.fetch(etapa, etapa)
    return "#{nome} › #{paradas_das_maquinas.map { |parada| parada.maquina.nome }.join(", ")}" if paradas_das_maquinas.any?
    return "#{nome} › todas as máquinas" if TrabalhoDaMaquina.ativos.exists?(trabalho: self.class.trabalhos_da_etapa(etapa))

    nome
  end

  def no_periodo?(ocorrencia)
    (data..(data_fim || data)).cover?(ocorrencia.data) && (turno_id.nil? || turno_id == ocorrencia.turno.id)
  end

  def para_quem?(chave_da_etapa, maquina_id)
    return paradas_das_maquinas.any? { |parada| parada.maquina_id == maquina_id } if paradas_das_maquinas.any?

    da_fabrica? || [ chave_da_etapa.to_s, LinhaDoPainel::SETOR_DA_ETAPA[chave_da_etapa.to_s] ].include?(etapa)
  end

  def periodo_em_ordem
    return unless data && data_fim && data_fim < data

    errors.add(:data_fim, "#{data_fim} is before the start #{data}; expected the same day or later")
  end

  # The machines picked do the stage's trabalho (Q1a: picked under a stage).
  def maquinas_da_etapa
    return if paradas_das_maquinas.empty?
    return errors.add(:maquinas, "need a stage; got machines for the whole factory") if etapa.nil?

    trabalhos = self.class.trabalhos_da_etapa(etapa)
    alheias = paradas_das_maquinas.map(&:maquina).reject { |maquina| maquina.trabalhos.any? { |feito| trabalhos.include?(feito.trabalho) } }
    errors.add(:maquinas, "#{alheias.map(&:nome).join(", ")} don't do the #{self.class.etapas.fetch(etapa, etapa)}") if alheias.any?
  end

  def etapa_conhecida
    self.etapa = etapa.presence
    return if etapa.nil? || self.class.etapas.key?(etapa)

    errors.add(:etapa, "#{etapa.inspect} is not a production stage; expected one of #{self.class.etapas.keys.join(", ")}")
  end
end
