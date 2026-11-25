# The factory's calendar (Painel 2/4a, decided 05/11/2026): the turnos the
# dono registered, laid on real days, minus the exceptions. It answers which
# turno is on now — after midnight too, a "Noite 22:00–06:00" started the
# day before (Q10a) — and how many hours a stage has in each turno ahead:
# none where the whole factory, or that stage, stops (Q8a). The queue and
# the previsão (2/4b) fill those hours by each stage's rhythm.
#
# Máquinas 3/5a (decided 24/11/2026): a stop may take some machines only —
# each whole, whatever stage it does (Q1a) —, so the hours are asked per
# machine too (maquina_id); and a stop that came back to work (voltou_em)
# gives the hours from that moment on.
#
# Usage: calendario = CalendarioDeProducao.new
#        calendario.agora&.rotulo # => "Manhã (06:00–14:00)"
#        calendario.ocorrencias(de: Time.current, ate: 3.days.from_now).map { |o| [ o.data, o.turno.nome ] }
#        calendario.horas(ocorrencia, "calandra") # => 0.0 when the Calandra stops that day
class CalendarioDeProducao
  # One turno on one day: the Friday's Noite runs from Friday 22:00 to Saturday 06:00.
  Ocorrencia = Struct.new(:turno, :data, :inicio, :fim, keyword_init: true) do
    def contem?(momento)
      momento >= inicio && momento < fim
    end

    def horas
      (fim - inicio) / 3600.0
    end

    def rotulo
      "#{turno.nome} (#{turno.horario})"
    end
  end

  # turnos / excecoes: given in specs; read from the database otherwise.
  def initialize(turnos: nil, excecoes: nil)
    @turnos = turnos || Turno.ativos.order(:inicio_min).to_a
    @excecoes = excecoes
  end

  # The turno on at that moment, or nil (between turnos, or the factory stopped).
  def agora(momento = Time.current)
    ocorrencias(de: momento - 1.day, ate: momento + 1.minute).find { |ocorrencia| ocorrencia.contem?(momento) }
  end

  # The next turno starting after the moment, within a week.
  # Usage: calendario.proxima(Time.current)&.inicio
  def proxima(momento = Time.current)
    ocorrencias(de: momento, ate: momento + 8.days).find { |ocorrencia| ocorrencia.inicio >= momento }
  end

  # The turnos that overlap the period, in order, without the ones the whole
  # factory doesn't work (a stage's stop only takes that stage's hours).
  def ocorrencias(de:, ate:)
    dias = (de.to_date - 1)..ate.to_date
    dias.flat_map { |data| do_dia(data) }
        .select { |ocorrencia| ocorrencia.fim > de && ocorrencia.inicio < ate }
        .reject { |ocorrencia| parada?(ocorrencia, nil) }
        .sort_by(&:inicio)
  end

  # Hours the stage — or its machine — has in the turno: none when it stops
  # there; from the moment on when the turno is under way, or when a stop
  # came back to work in it.
  # Usage: calendario.horas(ocorrencia, "calandra", maquina_id: calandra_2.id) # => 0.0 while it stops
  def horas(ocorrencia, chave_da_etapa, desde: nil, maquina_id: nil)
    comeco = comeco(ocorrencia, chave_da_etapa, desde: desde, maquina_id: maquina_id)
    comeco ? (ocorrencia.fim - comeco) / 3600.0 : 0.0
  end

  # When the free hours start in the turno (the queue lays its pieces from
  # there), or nil when it has none.
  # Usage: calendario.comeco(ocorrencia, "calandra", desde: Time.current) # => 10:15, the stop came back then
  def comeco(ocorrencia, chave_da_etapa, desde: nil, maquina_id: nil)
    ate = excecoes_do_dia(ocorrencia.data).filter_map { |excecao| excecao.parada_ate(ocorrencia, chave_da_etapa, maquina_id: maquina_id) }.max
    comeco = [ ocorrencia.inicio, desde, ate ].compact.max
    comeco if comeco < ocorrencia.fim
  end

  # Hours a sector has in the turno: the most of its stages that have work
  # there. The Estamparia's sector holds the calçado's Estamparia and the
  # tecido's Calandra, different machines that stop apart — read by the
  # sector's own name, a Calandra stop was never seen and an Estamparia one
  # left the Calandra's pieces in "2 h de 0 h" (fixed 19/11/2026; machines,
  # decision 6a, replace it). maquina_id: one machine's (Máquinas 3/5a).
  # Usage: calendario.horas_do_setor(ocorrencia, %w[estamparia calandra], desde: Time.current) # => 8.0
  def horas_do_setor(ocorrencia, chaves_das_etapas, desde: nil, maquina_id: nil)
    chaves_das_etapas.map { |chave| horas(ocorrencia, chave, desde: desde, maquina_id: maquina_id) }.max || 0.0
  end

  # The exceptions that stop the stages — or the machine — in the turno
  # (Máquinas 3/5b: the lane says which, until when).
  # Usage: calendario.paradas(ocorrencia, %w[calandra dublagem], maquina_id: calandra_2.id).map(&:nome) # => ["Manutenção"]
  def paradas(ocorrencia, chaves_das_etapas, maquina_id: nil)
    excecoes_do_dia(ocorrencia.data).select do |excecao|
      chaves_das_etapas.any? { |chave| excecao.parada_ate(ocorrencia, chave, maquina_id: maquina_id) }
    end
  end

  # The same calendar with one more exception (a stop not saved yet: its
  # impact, ImpactoDaParada).
  # Usage: calendario.com(parada).horas(ocorrencia, "calandra", maquina_id: calandra_2.id) # => 0.0
  def com(excecao)
    self.class.new(turnos: @turnos, excecoes: (@excecoes || ExcecaoCalendario.includes(:paradas_das_maquinas).to_a) + [ excecao ])
  end

  # Does the stage (nil: the whole factory) — or its machine — stop for the whole turno?
  def parada?(ocorrencia, chave_da_etapa, maquina_id: nil)
    comeco(ocorrencia, chave_da_etapa, maquina_id: maquina_id).nil?
  end

  private

  def do_dia(data)
    @turnos.select { |turno| turno.trabalha_em?(data) }.map do |turno|
      inicio = data.in_time_zone + (turno.inicio_min * 60)
      Ocorrencia.new(turno: turno, data: data, inicio: inicio, fim: inicio + (turno.duracao_min * 60))
    end
  end

  # A stop of several days (Máquinas 3/5a, Q6a) is on each of them.
  def excecoes_do_dia(data)
    @por_dia ||= (@excecoes || ExcecaoCalendario.includes(:paradas_das_maquinas).to_a).each_with_object(Hash.new { |dias, dia| dias[dia] = [] }) do |excecao, dias|
      (excecao.data..(excecao.data_fim || excecao.data)).each { |dia| dias[dia] << excecao }
    end
    @por_dia.fetch(data, [])
  end
end
