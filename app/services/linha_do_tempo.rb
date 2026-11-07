# The Painel's second view, the Linha do tempo (Painel 2/4c, decided
# 05–07/11/2026, inspired by Basecamp's Lineup): what comes ahead, by day,
# only to see. A window of 14 days (from 2 days before today by default,
# Q3a); each pedido a bar from its start to its previsão (FilaDeProducao) —
# done up to now, foreseen after, the part past the deadline apart —, the
# deadline's ◆, the line of now, the days without turno, and each sector's
# load per day. Going back in time shows only the record: when a pedido
# started and when it was delivered (Q16a).
#
# Groups: em_producao (in the queue, the original with its reposições as
# one bar), sem_previsao (something keeps it out, the reason said),
# pendentes (a draft or a sent pedido, its "se confirmar agora"), entregues
# (delivered inside the window). Order by arrival, previsão or deadline
# (Q6a); the waiting ones by arrival, the delivered latest first.
#
# The load of a sector on a day (Q2a): the hours the queue fills over the
# hours its turnos have — today only from now on, so never over 100%.
# Painel 3/4b (Q7a): today's is the larger of that and what the day's first
# photo programmed for today still to do (ProgramadoNaFila) — over the
# hours left, past 100%: the turno fell behind. A cliente final sees no
# load (Q4a): it is the factory's capacity.
#
# Usage: tempo = LinhaDoTempo.call(painel.linhas, fila: painel.fila, de: Date.current - 2)
#        tempo.dias.map(&:sem_turno)                    # => [false, true, …] (14)
#        tempo.grupos.first.barras.first.atraso         # => [72.1, 78.6] (% of the window)
#        tempo.cargas.first.celulas.map(&:percentual)   # => [nil, nil, 64, 100, 30, …]
class LinhaDoTempo
  DIAS = 14
  ANTES = 2
  ORDENS = %w[chegada previsao prazo].freeze
  SETORES = %w[impressao corte estamparia conferencia].freeze
  GRUPOS = { "em_producao" => "Em produção e na fila", "sem_previsao" => "Sem previsão",
             "pendentes" => "Pendentes de início", "entregues" => "Entregues" }.freeze
  # A pedido without previsão or deadline sorts after the others.
  NUNCA = Time.zone.local(9999, 12, 31)

  Dia = Struct.new(:data, :hoje, :sem_turno, keyword_init: true)
  Grupo = Struct.new(:chave, :nome, :barras, keyword_init: true)
  Carga = Struct.new(:setor, :celulas, keyword_init: true)
  # estado: :passado, :sem_turno, :parada, :encerrado (today's turnos are
  # over), :livre, :ok, :alto (85% or more), :cheio, :estourado (what was
  # programmed for today doesn't fit the hours left: programadas of livres).
  CelulaDaCarga = Struct.new(:data, :estado, :percentual, :programadas, :livres, keyword_init: true)

  # The window starting that day: 2 days before today when not given.
  def self.inicio_padrao(agora = Time.current)
    agora.to_date - ANTES
  end

  # linhas: the Painel's top rows (their reposições inside); entregues: the
  # rows delivered inside the window. calendario: the factory's (the queue's).
  # programado: what the photos programmed (ProgramadoNaFila), nil for none.
  def self.call(linhas, fila:, de:, entregues: [], agora: fila.agora, calendario: CalendarioDeProducao.new, ordem: "chegada", cliente_final: false, setores: SETORES, programado: nil)
    new(linhas, fila, de, entregues, agora, calendario, ordem, cliente_final, setores).tap { |tempo| tempo.programado = programado }
  end

  attr_writer :programado

  attr_reader :de, :ate, :agora, :ordem

  def initialize(linhas, fila, de, entregues, agora, calendario, ordem, cliente_final, setores)
    @linhas, @fila, @entregues = linhas, fila, entregues
    @de, @ate = de, de + DIAS
    @agora, @calendario = agora, calendario
    @ordem = ORDENS.include?(ordem) ? ordem : "chegada"
    @cliente_final = cliente_final
    @setores = setores
  end

  def dias
    @dias ||= (de...ate).map { |data| Dia.new(data: data, hoje: data == agora.to_date, sem_turno: ocorrencias_do_dia(data).empty?) }
  end

  # Only the groups with a bar inside the window, but the queue's, always shown.
  def grupos
    @grupos ||= barras.group_by(&:grupo).then do |por_grupo|
      GRUPOS.filter_map do |chave, nome|
        lista = por_grupo.fetch(chave, [])
        Grupo.new(chave: chave, nome: nome, barras: ordenar(chave, lista)) if lista.any? || chave == "em_producao"
      end
    end
  end

  # Each sector's load per day; none for a cliente final.
  def cargas
    return [] if @cliente_final

    @setores.map { |setor| Carga.new(setor: setor, celulas: dias.map { |dia| celula_da_carga(setor, dia.data) }) }
  end

  # The whole window before today: only the record.
  def no_passado?
    ate <= agora.to_date
  end

  # The window starts after the 90 days the queue reaches.
  def depois_da_fila?
    de.in_time_zone > agora + FilaDeProducao::HORIZONTE
  end

  # The line of now, in % of the window (nil outside it).
  def agora_em
    BarraNoTempo.posicao(agora, de, ate)
  end

  private

  def barras
    # The delivered ones the Etapas view asked for come again in @entregues.
    abertas = @linhas.reject { |linha| linha.pedido.status == "entregue" }
    (abertas + @entregues).map { |linha| BarraNoTempo.new(linha, agora, de, ate) }.select(&:na_janela?)
  end

  def ordenar(grupo, barras)
    return barras.sort_by { |b| -b.fim.to_f } if grupo == "entregues"
    return barras.sort_by { |b| [ b.linha.chegada, b.linha.pedido.id ] } unless grupo == "em_producao"

    barras.sort_by { |b| [ chave_da_ordem(b), b.linha.chegada, b.linha.pedido.id ] }
  end

  def chave_da_ordem(barra)
    { "chegada" => barra.linha.chegada, "previsao" => barra.fim || NUNCA, "prazo" => barra.prazo_fim || NUNCA }.fetch(ordem)
  end

  def celula_da_carga(setor, data)
    return CelulaDaCarga.new(data: data, estado: :passado) if data < agora.to_date

    turnos = ocorrencias_do_dia(data)
    return CelulaDaCarga.new(data: data, estado: :sem_turno) if turnos.empty?
    return CelulaDaCarga.new(data: data, estado: :parada) if turnos.all? { |ocorrencia| @calendario.parada?(ocorrencia, setor) }

    livres = turnos.sum { |ocorrencia| @calendario.horas(ocorrencia, setor, desde: agora) }
    return CelulaDaCarga.new(data: data, estado: :encerrado) unless livres.positive?

    percentual = [ (ocupadas(setor, data) / livres * 100).round, 100 ].min
    programadas = data == agora.to_date ? @programado&.pendentes_do_dia(setor) : nil
    return celula_estourada(data, programadas, livres) if programadas && programadas > livres + 0.01

    percentual = [ percentual, ((programadas || 0) / livres * 100).round ].max
    CelulaDaCarga.new(data: data, estado: estado_da_carga(percentual), percentual: percentual)
  end

  def celula_estourada(data, programadas, livres)
    CelulaDaCarga.new(data: data, estado: :estourado, percentual: (programadas / livres * 100).round, programadas: programadas, livres: livres)
  end

  def estado_da_carga(percentual)
    return :livre if percentual.zero?
    return :cheio if percentual >= 100

    percentual >= 85 ? :alto : :ok
  end

  # The hours the sector's queue fills that day.
  def ocupadas(setor, data)
    @ocupadas ||= Hash.new(0.0)
    @ocupadas_lidas ||= {}
    @ocupadas_lidas[setor] ||= @fila.do_setor(setor).each do |vez|
      vez.trechos.each { |trecho| @ocupadas[[ setor, trecho.ocorrencia.data ]] += trecho.horas }
    end
    @ocupadas[[ setor, data ]]
  end

  # The turnos the whole factory works that day (a turno past midnight is
  # the day it starts, Q10a).
  def ocorrencias_do_dia(data)
    @por_dia ||= @calendario.ocorrencias(de: de.in_time_zone, ate: ate.in_time_zone).group_by(&:data)
    @por_dia.fetch(data, [])
  end
end
