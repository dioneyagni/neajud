# The faixa's own timeline of one pedido (Painel 2/4c, Q5a; the axis of
# Q16a, 04/11/2026): a lane per stage of its path, a column per turno from
# now to its previsão, each stage's pieces in the queue (FilaDeProducao)
# filling the turnos they take. A stage done is marked done; one without
# previsão says why. A cliente final gets a column per day (Q4a).
#
# Painel 3/4b2 (decided 07/11/2026, Q8a): each stage's first plan
# (PlanoDaEtapa) drawn dashed, the columns starting at its first turno even
# when already over (the last 8 of those), and an arrow from the turno it
# was to end in to the one it ends in now. A cliente final gets no plan.
#
# Usage: tempo = TempoDoPedido.call(linha, fila: painel.fila, planos: { "impressao" => plano })
#        tempo.colunas.map(&:nome)                     # => ["Manhã", "Tarde", "Manhã"]
#        tempo.raias.map { |r| [ r.etapa.chave, r.estado ] } # => [["impressao", :feita], ["calandra", :prevista]]
#        tempo.raias.last.celulas                      # => [nil, 0.5, 1.0]
class TempoDoPedido
  # More than this many turnos: the rest is said, not drawn.
  COLUNAS = 24
  # Of them, at most this many already over (the plan's).
  PASSADAS = 8

  # inicio / fim: the turno's (or the day's) hours.
  # passada: already over (only a plan reaches back there).
  Coluna = Struct.new(:data, :nome, :inicio, :fim, :agora, :depois_do_prazo, :passada, keyword_init: true) do
    def horas
      (fim - inicio) / 3600.0
    end
  end
  # estado: :feita, :prevista, :andamento (some line had its baixa), :sem_previsao.
  # celulas: per column, the share of it the stage fills (nil: none);
  # planejadas the same for its plan (empty: none); seta when it ends in
  # another turno than planned.
  Raia = Struct.new(:etapa, :estado, :vez, :celulas, :planejadas, :seta, keyword_init: true)
  # de / para: the columns (indexes) of the planned end and of the end now,
  # clipped to the ones drawn; turnos: how many it moved (negative: earlier).
  Seta = Struct.new(:de, :para, :turnos, keyword_init: true)

  # nil when the pedido has nothing ahead in the queue.
  # planos: { etapa chave => PlanoDaEtapa } (the team's).
  def self.call(linha, fila:, cliente_final: false, planos: {})
    previsao = linha.previsao
    return if previsao.nil? || previsao.vezes.none? { |vez| vez.trechos.any? }

    new(linha, previsao, fila, cliente_final, cliente_final ? {} : planos)
  end

  attr_reader :colunas, :raias, :restantes

  def initialize(linha, previsao, fila, cliente_final, planos)
    @linha, @fila, @cliente_final, @planos = linha, fila, cliente_final, planos
    @vezes = previsao.vezes.index_by { |vez| vez.etapa.chave }
    todas = cliente_final ? por_dia(ocorrencias) : por_turno(ocorrencias)
    @colunas = todas.first(COLUNAS)
    @restantes = todas.size - @colunas.size
    @raias = linha.caminho.flatten.map { |etapa| raia(etapa) }
  end

  private

  # The turnos from the one under way (or the next) — or its plan's first,
  # the last PASSADAS of those already over — to its last piece, planned or now.
  def ocorrencias
    @ocorrencias ||= todas_as_ocorrencias.drop(cortadas)
  end

  def todas_as_ocorrencias
    @todas_as_ocorrencias ||= begin
      periodos = @vezes.values.flat_map(&:trechos).map { |trecho| [ trecho.inicio, trecho.fim ] } + @planos.values.flat_map(&:periodos)
      de = [ @fila.agora, *periodos.map(&:first) ].min
      @fila.calendario.ocorrencias(de: de, ate: periodos.map(&:last).max)
    end
  end

  # The turnos over, past the PASSADAS drawn.
  def cortadas
    [ todas_as_ocorrencias.count { |ocorrencia| ocorrencia.fim <= @fila.agora } - PASSADAS, 0 ].max
  end

  def por_turno(ocorrencias)
    ocorrencias.map do |ocorrencia|
      Coluna.new(data: ocorrencia.data, nome: ocorrencia.turno.nome, inicio: ocorrencia.inicio, fim: ocorrencia.fim,
                 agora: ocorrencia.contem?(@fila.agora), depois_do_prazo: depois_do_prazo?(ocorrencia.data),
                 passada: ocorrencia.fim <= @fila.agora)
    end
  end

  def por_dia(ocorrencias)
    ocorrencias.group_by(&:data).map do |data, do_dia|
      Coluna.new(data: data, inicio: do_dia.map(&:inicio).min, fim: do_dia.map(&:fim).max,
                 agora: data == @fila.agora.to_date, depois_do_prazo: depois_do_prazo?(data))
    end
  end

  def depois_do_prazo?(data)
    @linha.prazo.present? && data > @linha.prazo
  end

  def raia(etapa)
    vez = @vezes[etapa.chave]
    return Raia.new(etapa: etapa, estado: :feita, celulas: [], planejadas: []) unless vez
    return Raia.new(etapa: etapa, estado: :sem_previsao, vez: vez, celulas: [], planejadas: []) unless vez.fim

    plano = @planos[etapa.chave]
    periodos = vez.trechos.map { |trecho| [ trecho.inicio, trecho.fim ] }
    Raia.new(etapa: etapa, estado: vez.iniciada? ? :andamento : :prevista, vez: vez, celulas: colunas.map { |coluna| parte(periodos, coluna) },
             planejadas: plano ? colunas.map { |coluna| parte(plano.periodos, coluna) } : [], seta: plano && seta(plano.fim, vez.fim))
  end

  # The share of the column the pieces fill.
  def parte(periodos, coluna)
    horas = periodos.sum { |inicio, fim| [ [ fim, coluna.fim ].min - [ inicio, coluna.inicio ].max, 0 ].max } / 3600.0
    horas.positive? ? [ horas / coluna.horas, 1.0 ].min.round(2) : nil
  end

  # nil when it still ends in the turno planned.
  def seta(planejado, agora)
    de, para = turno_do_fim(planejado), turno_do_fim(agora)
    return if de.nil? || para.nil? || de == para

    ultima = colunas.size - 1
    Seta.new(de: (de - cortadas).clamp(0, ultima), para: (para - cortadas).clamp(0, ultima), turnos: para - de)
  end

  # The index of the turno a stage ending then ends in (among them all).
  def turno_do_fim(momento)
    todas_as_ocorrencias.index { |ocorrencia| ocorrencia.inicio < momento && momento <= ocorrencia.fim }
  end
end
