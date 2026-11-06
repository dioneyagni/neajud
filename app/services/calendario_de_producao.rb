# The factory's calendar (Painel 2/4a, decided 05/11/2026): the turnos the
# dono registered, laid on real days, minus the exceptions. It answers which
# turno is on now — after midnight too, a "Noite 22:00–06:00" started the
# day before (Q10a) — and how many hours a stage has in each turno ahead:
# none where the whole factory, or that stage, stops (Q8a). The queue and
# the previsão (2/4b) fill those hours by each stage's rhythm.
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

  # Hours the stage has in the turno: none when it stops there; from the
  # moment on when the turno is under way.
  def horas(ocorrencia, chave_da_etapa, desde: nil)
    return 0.0 if parada?(ocorrencia, chave_da_etapa)

    comeco = [ ocorrencia.inicio, desde ].compact.max
    [ (ocorrencia.fim - comeco) / 3600.0, 0.0 ].max
  end

  def parada?(ocorrencia, chave_da_etapa)
    excecoes_do_dia(ocorrencia.data).any? { |excecao| excecao.para?(ocorrencia, chave_da_etapa) }
  end

  private

  def do_dia(data)
    @turnos.select { |turno| turno.trabalha_em?(data) }.map do |turno|
      inicio = data.in_time_zone + (turno.inicio_min * 60)
      Ocorrencia.new(turno: turno, data: data, inicio: inicio, fim: inicio + (turno.duracao_min * 60))
    end
  end

  def excecoes_do_dia(data)
    @por_dia ||= (@excecoes || ExcecaoCalendario.all.to_a).group_by(&:data)
    @por_dia.fetch(data, [])
  end
end
