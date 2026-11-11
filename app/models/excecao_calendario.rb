# A day — or one turno of it — the factory, or one stage, doesn't work
# (Painel 2/4a, decided 05/11/2026, Q8a): a holiday, a recess, the Calandra
# stopped for maintenance. The previsão (2/4b) skips it: the stage has no
# capacity there. A national holiday the dono confirms is one too, with
# origem "feriado" (FeriadosNacionais suggests them, Q9a).
#
# Removed physically, like a molde's price: it is a setting about the
# future, and the baixas already given keep their own times.
#
# Usage: ExcecaoCalendario.create!(data: Date.new(2026, 11, 13), nome: "Calandra parada", etapa: "calandra")
#        excecao.para?(ocorrencia, "calandra") # => true
class ExcecaoCalendario < ApplicationRecord
  include GeraUuid
  include AvisaAFila

  self.table_name = "excecoes_calendario"

  ORIGENS = %w[manual feriado].freeze

  belongs_to :turno, optional: true
  atribui_por_uuid :turno

  validates :data, presence: true
  validates :nome, presence: true
  validates :origem, inclusion: { in: ORIGENS }
  validates :data, uniqueness: { conditions: -> { where(origem: "feriado") }, message: "already has its national holiday" }, if: -> { origem == "feriado" }
  validate :etapa_conhecida

  scope :do_ano, ->(ano) { where(data: Date.new(ano, 1, 1)..Date.new(ano, 12, 31)) }

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

  # Does it stop this occurrence (CalendarioDeProducao::Ocorrencia) for the
  # stage? nil etapa asks about the whole factory. The Dublagem's stops the
  # Dublagem final too, its sector's (5b1c2).
  def para?(ocorrencia, chave_da_etapa = nil)
    return false unless ocorrencia.data == data && (turno_id.nil? || turno_id == ocorrencia.turno.id)

    da_fabrica? || [ chave_da_etapa.to_s, LinhaDoPainel::SETOR_DA_ETAPA[chave_da_etapa.to_s] ].include?(etapa)
  end

  # Usage: excecao.abrangencia # => "Calandra · Tarde" / "toda a fábrica · dia inteiro"
  def abrangencia
    [ da_fabrica? ? "toda a fábrica" : self.class.etapas.fetch(etapa, etapa), turno ? turno.nome : "dia inteiro" ].join(" · ")
  end

  private

  def etapa_conhecida
    self.etapa = etapa.presence
    return if etapa.nil? || self.class.etapas.key?(etapa)

    errors.add(:etapa, "#{etapa.inspect} is not a production stage; expected one of #{self.class.etapas.keys.join(", ")}")
  end
end
