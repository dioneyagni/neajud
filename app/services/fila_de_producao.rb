# The queue of each production sector and every pedido's previsão (Painel
# 2/4b, decided 05–06/11/2026). A queue per sector (a column of the Painel:
# the tecido's Calandra is in the Estamparia's), in arrival order — the
# confirmation (Q1a) —, each pedido taking the hours of its tipo's rhythm
# (Q4a): what its open lines weigh (CargaDaEtapa) over the rhythm in use.
# The hours are filled turno by turno from now (the turno under way only
# what is left of it), where the stage works (CalendarioDeProducao); a stage
# starts when the ones it waits for (`trava`) end for that pedido.
#
# What leaves a stage without previsão, and every stage that waits for it:
#   - a missing material (Q1c, 06/11/2026) holds only the stage that takes it
#     from the stock — without fabric the Impressão still runs and the Corte
#     waits —; a held stage takes no place in the queue;
#   - a stage without rhythm (Q2a);
#   - a queue going past 90 days ahead.
#
# A draft or a sent pedido is not in the queue: `se_confirmar` places it
# after everyone, pushing no one (Q1c).
#
# Painel 3/4a (decided 07/11/2026): a person may move a stage in its
# sector's queue (MovimentoDaFila, the order in force given as `ordens`).
# Each sector's queue then goes in its own order — first the stages already
# under way (some line had its baixa, Q6b: no one passes them), then the
# moved ones where they were put and the others by arrival —, sector by
# sector, each stage still waiting for the ones it depends on.
#
# It reads the whole factory — the pedidos, the calendar, the rhythms — even
# for a cliente final, whose previsão depends on everyone else's pedidos
# (like AguardandoMaterial); what a person sees of it is filtered by who
# asks: the Painel shows only the visible rows, and a cliente final no queue.
#
# Usage: fila = FilaDeProducao.call
#        fila.previsao(pedido).fim                 # => Thu, 12 Nov 2026 15:30
#        fila.do_setor("impressao").map(&:posicao) # => [1, 2, 3, nil]
#        fila.se_confirmar(rascunho).fim
class FilaDeProducao
  HORIZONTE = 90.days
  ATIVOS = %w[confirmado em_producao].freeze
  # Dublagem 5b1c2 (Q3b, 11/11/2026): the sectors whose queue holds a stage
  # waiting for another sector midway (the Dublagem final, the Calandra):
  # it never holds the ones behind it — among those whose stages waited
  # for are placed, the one that may start first goes, the order breaking
  # ties.
  SETORES_PELO_PRONTO = %w[dublagem].freeze

  # A stage's piece inside one turno.
  Trecho = Struct.new(:ocorrencia, :inicio, :fim, keyword_init: true) do
    def horas
      (fim - inicio) / 3600.0
    end
  end

  # One stage of one pedido in its sector's queue. fim nil: no previsão,
  # motivo says why (falta: a material is missing). espera: the stage it
  # waits for, when that one ends after now. abertas / total: its lines.
  # movimento: the MovimentoDaFila that put it where it is (nil: arrival).
  # linhas, antes (the open stages it waits for), preso (the materials
  # holding it), ordem and colocada are how the queue builds it.
  # retidas: a dublagem's open lines a missing material holds (5b1c3, Q3a) —
  # the stage goes with the free ones (linhas); retidas_por: those materials.
  Vez = Struct.new(:pedido, :etapa, :setor, :posicao, :carga, :horas, :inicio, :fim, :trechos, :espera,
                   :motivo, :falta, :abertas, :total, :sem_medida, :movimento, :linhas, :antes, :preso, :ordem, :colocada,
                   :retidas, :retidas_por, keyword_init: true) do
    # Some line already had its baixa.
    def iniciada?
      abertas < total
    end

    # Usage: vez.motivo_das_retidas # => "previsão quando Espuma TC4 Branco-1.40 m entrar"
    def motivo_das_retidas
      "previsão quando #{retidas_por.map(&:nome_completo).join(" e ")} entrar" if retidas.present?
    end
  end

  # The pedido's open stages. motivo: why none can be computed (a draft
  # with pendências).
  Previsao = Struct.new(:pedido, :vezes, :motivo, :se_confirmar, keyword_init: true) do
    # When its last stage ends; nil when some stage has no previsão.
    # A letra held by a missing material leaves it without one too (5b1c3).
    def fim
      return if vezes.empty? || vezes.any? { |vez| vez.fim.nil? || vez.retidas.present? }

      vezes.map(&:fim).max
    end

    def sem_previsao
      self[:motivo] || vezes.find { |vez| vez.fim.nil? }&.motivo || vezes.filter_map(&:motivo_das_retidas).first
    end

    # Every stage done: only the delivery is left.
    def pronta?
      vezes.empty? && self[:motivo].nil?
    end

    # Its next piece of work from the moment on (the block it is in, Q3a).
    def proxima(agora)
      vezes.flat_map(&:trechos).select { |trecho| trecho.fim >= agora }.min_by(&:inicio)
    end

    # Days left between the previsão and the deadline; negative: late.
    def folga(prazo)
      prazo && fim && (prazo - fim.to_date).to_i
    end
  end

  # Where each sector's queue is: the moment it is free and the material the
  # cutting machine ended on (the troca between pedidos, Painel 2/4a2 A6b).
  Agenda = Struct.new(:livre, :ultimo_material) do
    def copia
      Agenda.new(livre.dup, ultimo_material.dup)
    end
  end

  # estados: { pedido id => EstadoDasEtapas } already read (the Painel's);
  # the others are read here. ordens: { [pedido id, etapa] => MovimentoDaFila }
  # in force. The rest is read when not given (specs).
  def self.call(agora: Time.current, calendario: CalendarioDeProducao.new, estados: {}, aguardando: nil, ritmos: nil, ordens: nil)
    new(agora, calendario, estados, aguardando, ritmos, ordens).tap(&:montar)
  end

  # estados: every pedido's stage states it read (a second queue reuses them);
  # ordens: the moved stages it went by.
  attr_reader :agora, :ocorrencias, :estados, :calendario, :ordens

  def initialize(agora, calendario, estados, aguardando, ritmos, ordens = nil)
    @agora = agora
    @calendario = calendario
    @ordens = ordens || MovimentoDaFila.ordens
    @estados = estados.dup
    @aguardando = aguardando || AguardandoMaterial.call
    @ritmos = (ritmos || RitmoProducao.all.to_a).index_by { |ritmo| [ ritmo.tipo, ritmo.etapa ] }
    @medidas = RitmoMedido.call(calendario, ate: agora, ritmos: @ritmos.values)
    @ocorrencias = calendario.ocorrencias(de: agora, ate: agora + HORIZONTE)
    @agenda = Agenda.new(Hash.new(agora), {})
    @filas = Hash.new { |filas, setor| filas[setor] = [] }
    @previsoes = {}
    @memoria = {}
  end

  def montar
    pedidos = Pedido.ativos.where(status: ATIVOS).includes(:client, :reposicao_de, itens_pedido: :arte).to_a
    ler_estados(pedidos)
    vezes = pedidos.flat_map do |pedido|
      presas = letras_presas(pedido)
      abertas = abrir(pedido, @estados.fetch(pedido.id), materiais_presos(pedido, presas), presas)
      @previsoes[pedido.id] = Previsao.new(pedido: pedido, vezes: abertas, se_confirmar: false)
      abertas
    end
    agendar(vezes)
  end

  # The pedidos in the queue.
  def pedidos
    @previsoes.values.map(&:pedido)
  end

  # The aguardando and rhythms it read, for a second queue (the impact of a move).
  def entradas
    { agora: agora, calendario: @calendario, estados: @estados, aguardando: @aguardando, ritmos: @ritmos.values }
  end

  # Usage: fila.previsao(pedido) # => nil for a pedido not in the queue (a draft)
  def previsao(pedido)
    @previsoes[pedido.id]
  end

  # A draft or a sent pedido's previsão if confirmed now (Q1c): after the
  # whole queue, moving no one; nothing when it has pendências (its lines
  # are not all known yet).
  # Usage: fila.se_confirmar(rascunho, pendencias: linha.bloqueios.any?).fim
  def se_confirmar(pedido, pendencias: false)
    return Previsao.new(pedido: pedido, vezes: [], motivo: "resolva as pendências para ter a previsão", se_confirmar: true) if pendencias

    estados = @estados[pedido.id] ||= EstadoDasEtapas.call(pedido)
    agenda = @agenda.copia
    Previsao.new(pedido: pedido, vezes: abrir(pedido, estados, {}).each { |vez| colocar(vez, agenda) }, se_confirmar: true)
  end

  # The sector's queue: its stages with previsão in order, then the ones without.
  # Usage: fila.do_setor("corte").map { |vez| [ vez.posicao, vez.pedido.uuid.first(8) ] }
  def do_setor(setor)
    @filas[setor]
  end

  # The turnos the sector's queue fills, each with its pieces and the hours
  # it has (from now on, for the one under way).
  # Usage: fila.turnos_do_setor("impressao").first.livres # => 3.5
  def turnos_do_setor(setor)
    pecas = do_setor(setor).flat_map { |vez| vez.trechos.map { |trecho| [ vez, trecho ] } }
    pecas.group_by { |_, trecho| trecho.ocorrencia }.map do |ocorrencia, do_turno|
      TurnoDaFila.new(ocorrencia: ocorrencia, pecas: do_turno, livres: @calendario.horas(ocorrencia, setor, desde: agora))
    end
  end

  TurnoDaFila = Struct.new(:ocorrencia, :pecas, :livres, keyword_init: true) do
    def ocupadas
      pecas.sum { |_, trecho| trecho.horas }
    end
  end

  # The sector whose queue a stage is in: its Painel column, but the
  # Dublagem final's is the Dublagem's (5b1c2, Q2a: one machine).
  def self.setor_de(etapa)
    LinhaDoPainel::SETOR_DA_ETAPA.fetch(etapa.chave) { LinhaDoPainel::COLUNA_DA_ETAPA.fetch(etapa.chave, etapa.chave) }
  end

  private

  # One query for every pedido's baixas the Painel didn't read.
  def ler_estados(pedidos)
    faltam = pedidos.reject { |pedido| @estados.key?(pedido.id) }
    baixas = BaixaProducao.vigentes.where(pedido_id: faltam.map(&:id)).includes(:user).group_by(&:pedido_id)
    faltam.each { |pedido| @estados[pedido.id] = EstadoDasEtapas.call(pedido, baixas: baixas.fetch(pedido.id, [])) }
  end

  def entrar_na_fila(vez)
    fila = @filas[vez.setor]
    vez.posicao = fila.count(&:fim) + 1 if vez.fim
    # The ones without previsão after the others.
    vez.fim ? fila.insert(fila.index { |outra| outra.fim.nil? } || fila.size, vez) : fila << vez
  end

  # Its stages with open lines, not placed yet, each knowing the open ones
  # it waits for (a done one waits for nothing).
  # presas: the dublagem lines a missing material holds (5b1c3, Q3a): the
  # stage goes with the free ones; all held, it is held by those materials.
  def abrir(pedido, estados, presos, presas = {})
    abertas = {}
    EtapasProducao.do_tipo(pedido.tipo, pedido: pedido).each_with_index.filter_map do |etapa, indice|
      situacoes = estados.fetch(etapa.chave, {}).values
      linhas = situacoes.reject { |situacao| situacao.estado == :feita }.map(&:linha)
      next if linhas.empty?

      retidas, livres = linhas.partition { |linha| presas.key?(linha.chave) }
      retidas_por = retidas.flat_map { |linha| presas[linha.chave] }.uniq
      preso = livres.empty? ? (presos[etapa.chave] || []) | retidas_por : presos[etapa.chave]
      abertas[etapa.chave] = Vez.new(pedido: pedido, etapa: etapa, setor: self.class.setor_de(etapa), trechos: [], sem_medida: [],
                                     abertas: linhas.size, total: situacoes.size, linhas: livres.presence || retidas, preso: preso.presence,
                                     retidas: (retidas if livres.any?), retidas_por: retidas_por,
                                     antes: etapa.trava.filter_map { |trava| abertas[trava] }, movimento: @ordens[[ pedido.id, etapa.chave ]]).tap do |vez|
        vez.ordem = ordem_de(vez, indice)
      end
    end
  end

  # The pedido's open dublagem lines a missing material holds (MateriaisDaLetra).
  def letras_presas(pedido)
    faltas = @aguardando.do_pedido(pedido)
    return {} if faltas.empty?

    estados = @estados.fetch(pedido.id)
    linhas = LinhasDeProducao::MOMENTO_DA_ETAPA.keys.flat_map { |chave| estados.fetch(chave, {}).values }
    MateriaisDaLetra.presas(linhas.reject { |situacao| situacao.estado == :feita }.map(&:linha), faltas)
  end

  # Under way first, in arrival order; then the moved ones as if they had
  # arrived when they were put, the others by arrival. A stage not moved
  # itself follows the one it waits for that was (the latest of them, if
  # several): moving a pedido's Impressão takes its Calandra along.
  def ordem_de(vez, indice)
    chegada = vez.pedido.confirmado_em || vez.pedido.created_at
    return [ 0, chegada, vez.pedido.id, indice ] if vez.iniciada?

    [ 1, vez.movimento&.ordem_em || seguida(vez) || chegada, vez.pedido.id, indice ]
  end

  def seguida(vez)
    vez.antes.reject(&:iniciada?).select { |antes| antes.movimento || antes.ordem[1] != (antes.pedido.confirmado_em || antes.pedido.created_at) }.map { |antes| antes.ordem[1] }.max
  end

  # Each sector's queue in its order, sector by sector: a sector's next
  # stage goes once the ones it waits for are placed, holding the ones after
  # it (the strict order).
  def agendar(vezes)
    filas = vezes.group_by(&:setor).transform_values { |do_setor| do_setor.sort_by(&:ordem) }
    until filas.values.all?(&:empty?)
      colocadas = filas.values.sum { |fila| colocar_as_primeiras(fila) }
      destravar(filas) if colocadas.zero?
    end
  end

  def colocar_as_primeiras(fila)
    return colocar_pelo_pronto(fila) if SETORES_PELO_PRONTO.include?(fila.first&.setor)

    colocadas = 0
    while (vez = fila.first) && vez.antes.all?(&:colocada)
      entrar_na_fila(colocar(fila.shift, @agenda))
      colocadas += 1
    end
    colocadas
  end

  def colocar_pelo_pronto(fila)
    colocadas = 0
    while (indice = proxima_pronta(fila))
      entrar_na_fila(colocar(fila.delete_at(indice), @agenda))
      colocadas += 1
    end
    colocadas
  end

  # The index of the one to place next: among the front ones whose stages
  # waited for are placed (when they end is known), the earliest start; nil
  # when the first still waits for one not placed.
  def proxima_pronta(fila)
    conhecidas = fila.take_while { |vez| vez.antes.all?(&:colocada) }
    conhecidas.each_index.min_by { |indice| [ [ @agenda.livre[conhecidas[indice].setor], pronto(conhecidas[indice]) ].max, indice ] }
  end

  def pronto(vez) = ([ agora ] + vez.antes.filter_map(&:fim)).max

  # Every sector's next stage waits for one behind it in its own sector (a
  # stage moved ahead of the one it waits for): that one goes first.
  def destravar(filas)
    vez = filas.values.find(&:any?).first
    vez = vez.antes.find { |outra| !outra.colocada } until vez.antes.all?(&:colocada)
    filas[vez.setor].delete(vez)
    filas[vez.setor].unshift(vez)
  end

  # Places it after the stages it waits for (their Vez in antes).
  def colocar(vez, agenda)
    vez.colocada = true
    sem = vez.antes.find { |outra| outra.fim.nil? }
    return vez.tap { |v| v.motivo, v.falta = sem.motivo, sem.falta } if sem
    return vez.tap { |v| v.motivo, v.falta = "previsão quando #{v.preso.map(&:nome_completo).join(" e ")} entrar", true } if vez.preso

    ritmo = @ritmos[[ vez.pedido.tipo, vez.etapa.chave ]] || RitmoProducao.new(tipo: vez.pedido.tipo, etapa: vez.etapa.chave)
    carga = CargaDaEtapa.call(vez.pedido, vez.etapa, vez.linhas, ritmo, anterior: agenda.ultimo_material[vez.setor], memoria: @memoria)
    horas = ritmo.horas(carga.valor, @medidas[[ vez.pedido.tipo, vez.etapa.chave ]])
    return vez.tap { |v| v.motivo = "#{v.etapa.nome} (#{Pedido::ROTULOS_DOS_TIPOS[v.pedido.tipo]}) sem ritmo" } unless horas

    vez.espera = vez.antes.select { |outra| outra.fim > agora }.max_by(&:fim)
    encher(vez, carga, horas, pronto(vez), agenda)
  end

  def encher(vez, carga, horas, pronto, agenda)
    vez.carga, vez.horas, vez.sem_medida = carga.valor, horas, carga.sem_medida
    vez.trechos, vez.fim = trechos(vez.etapa.chave, [ agenda.livre[vez.setor], pronto ].max, horas)
    vez.inicio = vez.trechos.first&.inicio
    agenda.livre[vez.setor] = vez.fim || agora + HORIZONTE
    agenda.ultimo_material[vez.setor] = carga.ultimo_material if carga.ultimo_material
    vez.motivo = ocorrencias.empty? ? "sem turnos cadastrados" : "a fila passa de 90 dias" unless vez.fim
    vez.trechos = [] unless vez.fim
    vez
  end

  # The turnos' hours the stage fills from the moment on; the end is nil
  # when they run out before the hours do.
  def trechos(chave, desde, horas)
    indice = ocorrencias.bsearch_index { |ocorrencia| ocorrencia.fim > desde }
    return [ [], nil ] unless indice

    restante = horas
    ocorrencias[indice..].each_with_object([]) do |ocorrencia, pecas|
      livres = @calendario.horas(ocorrencia, chave, desde: desde)
      next unless livres.positive?

      comeco = [ ocorrencia.inicio, desde ].max
      usadas = [ livres, restante ].min
      pecas << Trecho.new(ocorrencia: ocorrencia, inicio: comeco, fim: desde = comeco + (usadas * 3600))
      restante -= usadas
      return [ pecas, desde ] if restante <= 1e-6
    end.then { |pecas| [ pecas, nil ] }
  end

  # The stage each missing material holds (Q1c): the one that takes it from
  # the stock; one only letras take holds those letras (5b1c3, Q1a: presas),
  # one nothing takes (a dublado of 5a) the first stage.
  def materiais_presos(pedido, presas = {})
    etapas = EtapasProducao.do_tipo(pedido.tipo, pedido: pedido)
    das_letras = presas.values.flatten.to_set
    @aguardando.do_pedido(pedido).each_with_object({}) do |falta, presos|
      etapa = etapas.find { |e| materiais_da(pedido, e).include?(falta.materia_prima) }
      next if etapa.nil? && das_letras.include?(falta.materia_prima)

      etapa ||= etapas.first
      (presos[etapa.chave] ||= []) << falta.materia_prima
    end
  end

  def materiais_da(pedido, etapa)
    return [] unless etapa.ajusta_estoque?
    return [ pedido.material_de_impressao ].compact if etapa.material == "impressao"

    @estados.fetch(pedido.id).fetch(etapa.chave, {}).values.filter_map { |situacao| situacao.linha.materia_prima }
  end
end
