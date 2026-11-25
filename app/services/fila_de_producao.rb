# The queue of each production sector and every pedido's previsão (Painel
# 2/4b, decided 05–06/11/2026). A queue per sector (a column of the Painel:
# the tecido's Calandra is in the Estamparia's), in arrival order — the
# confirmation (Q1a) —, each pedido taking the hours of its tipo's rhythm
# (Q4a): what its open lines weigh (CargaDaEtapa) over the rhythm in use.
# The hours are filled turno by turno from now (the turno under way only
# what is left of it), where the stage works (CalendarioDeProducao); a stage
# starts when the ones it waits for (`trava`) end for that pedido.
#
# Máquinas 2/5a (decided 20–21/11/2026): the hours go on a machine — each
# active one doing the stage's trabalho (RecursosDaFila), the piece on the
# one that ends it first (Q3a), at that machine's speed; a trabalho with no
# machine is its sector's one agenda, as before (Q7a). A machine is one
# agenda whatever it does (Q1a: the Calandra 2 calandra and dubla, its time
# shared by arrival). And no strict order any more (Q2a): see `agendar`.
# Máquinas 2/5b (Q3a): a stage a person sent to a machine (`fixacoes`,
# MovimentoDaFila) goes only on it while it does the trabalho and is active;
# else back to the automatic.
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
# The order is first the stages already under way (some line had its
# baixa, Q6b: no one passes them), then the moved ones where they were put
# and the others by arrival; each stage still waits for the ones it depends on.
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
  # recurso: the agenda it went on (RecursosDaFila), maquina: that Maquina
  # (nil: its sector's, a trabalho with no machine). fixacao: the
  # MovimentoDaFila holding it on a machine (2/5b), nil when automatic.
  # maquina_da_baixa: the machine id of its last baixa (4/5a, Q1a) — a
  # started stage stays there until it ends, over any hold.
  # linhas, antes (the open stages it waits for), preso (the materials
  # holding it), ordem and colocada are how the queue builds it.
  # retidas: a dublagem's open lines a missing material holds (5b1c3, Q3a) —
  # the stage goes with the free ones (linhas); retidas_por: those materials.
  Vez = Struct.new(:pedido, :etapa, :setor, :posicao, :carga, :horas, :inicio, :fim, :trechos, :espera,
                   :motivo, :falta, :abertas, :total, :sem_medida, :movimento, :linhas, :antes, :preso, :ordem, :colocada,
                   :retidas, :retidas_por, :recurso, :maquina, :fixacao, :maquina_da_baixa, keyword_init: true) do
    # Some line already had its baixa.
    def iniciada?
      abertas < total
    end

    # Usage: vez.motivo_das_retidas # => "previsão quando Espuma TC4 Branco-1.40 m entrar"
    def motivo_das_retidas
      "previsão quando #{retidas_por.map(&:nome_completo).join(" e ")} entrar" if retidas.present?
    end
  end

  # Where each resource is (a machine, or a sector with none — Máquinas
  # 2/5a): the moment it is free and the material a cutting machine ended
  # on (the troca between pedidos, Painel 2/4a2 A6b; per machine, Q8a).
  Agenda = Struct.new(:livre, :ultimo_material) do
    def copia
      Agenda.new(livre.dup, ultimo_material.dup)
    end
  end

  # estados: { pedido id => EstadoDasEtapas } already read (the Painel's);
  # the others are read here. ordens, fixacoes: { [pedido id, etapa] =>
  # MovimentoDaFila } in force — the moved stages, the ones held on a
  # machine. The rest is read when not given (specs).
  def self.call(agora: Time.current, calendario: CalendarioDeProducao.new, estados: {}, aguardando: nil, ritmos: nil, ordens: nil, fixacoes: nil)
    new(agora, calendario, estados, aguardando, ritmos, ordens, fixacoes).tap(&:montar)
  end

  # estados: every pedido's stage states it read (a second queue reuses them);
  # ordens, fixacoes: the moved and the held stages it went by.
  attr_reader :agora, :ocorrencias, :estados, :calendario, :ordens, :fixacoes

  def initialize(agora, calendario, estados, aguardando, ritmos, ordens = nil, fixacoes = nil)
    @agora = agora
    @calendario = calendario
    @ordens = ordens || MovimentoDaFila.ordens
    @fixacoes = fixacoes || MovimentoDaFila.fixacoes
    @estados = estados.dup
    @aguardando = aguardando || AguardandoMaterial.call
    # Máquinas 1/5: each with its machines, read once.
    @ritmos = RitmoProducao.da_fabrica(ritmos || RitmoProducao.all.to_a)
    @recursos = RecursosDaFila.new(@ritmos, calendario)
    @opcoes = {}.compare_by_identity
    @cargas = {}
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
    numerar_pelo_inicio
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

  # The turnos the sector's queue fills, each with its pieces, a lane per
  # resource (Máquinas 2/5a: its machines, or the sector with none) and the
  # hours they have summed (from now on, for the one under way); the pieces
  # another sector put on its machines (outras, Q1a) count as taken.
  # Usage: fila.turnos_do_setor("impressao").first.livres # => 7.0 (two machines, 3.5 h left)
  def turnos_do_setor(setor)
    recursos = recursos_do_setor(setor)
    outras = pecas_de(de_outros_setores(setor))
    pecas_de(do_setor(setor)).group_by { |_, trecho| trecho.ocorrencia }.map do |ocorrencia, do_turno|
      de_fora = outras.select { |_, trecho| trecho.ocorrencia == ocorrencia }
      raias = recursos.map do |recurso, etapas|
        RaiaDoTurno.new(recurso: recurso, livres: @calendario.horas_do_setor(ocorrencia, etapas, desde: agora),
                        pecas: (do_turno + de_fora).select { |vez, _| vez.recurso == recurso.chave })
      end
      TurnoDaFila.new(ocorrencia: ocorrencia, pecas: do_turno, outras: de_fora, raias: raias, livres: raias.sum(&:livres))
    end
  end

  # The hours the sector has in a turno, its resources' summed (the Linha do
  # tempo's load, Máquinas 2/5a).
  # Usage: fila.horas_do_setor(ocorrencia, "estamparia") # => 12.0 (three calandras, 4 h)
  def horas_do_setor(ocorrencia, setor, desde: agora)
    recursos_do_setor(setor).sum { |_, etapas| @calendario.horas_do_setor(ocorrencia, etapas, desde: desde) }
  end

  # The machines a stage may go on (2/5b: where it may be sent), in lane order.
  # Usage: fila.maquinas_para(vez).map(&:nome) # => ["Calandra 2", "Calandra 3"]
  def maquinas_para(vez)
    @recursos.do_ritmo(ritmo_de(vez), vez.setor).filter_map(&:maquina)
  end

  # The sector's resources with the stages each does there (RecursosDaFila#do_setor):
  # for the type × stage pairs in its queue, or every one of the sector when empty.
  def recursos_do_setor(setor)
    pares = do_setor(setor).map { |vez| [ vez.pedido.tipo, vez.etapa.chave ] }.uniq.presence ||
            @ritmos.keys.select { |tipo, etapa| self.class.setor_de(EtapasProducao.etapa(tipo, etapa)) == setor }
    @recursos.do_setor(setor, pares)
  end

  # Other sectors' stages on this sector's machines (Q1a: the Calandra 2
  # dubbing, seen from the Estamparia).
  # Usage: fila.de_outros_setores("estamparia").map { |vez| vez.etapa.chave } # => ["dublagem"]
  def de_outros_setores(setor)
    maquinas = recursos_do_setor(setor).map { |recurso, _| recurso.chave if recurso.maquina? }.compact
    return [] if maquinas.empty?

    @filas.except(setor).values.flatten.select { |vez| maquinas.include?(vez.recurso) }
  end

  # The stages whose hours count for the sector: the ones in its queue, or
  # every stage of it when the queue is empty.
  # Usage: fila.etapas_do_setor("estamparia") # => ["calandra"] in a tecido-only factory
  def etapas_do_setor(setor)
    na_fila = do_setor(setor).map { |vez| vez.etapa.chave }.uniq
    return na_fila if na_fila.any?

    EtapasProducao.todas.values.flatten.select { |etapa| self.class.setor_de(etapa) == setor }.map(&:chave).uniq
  end

  # A stage's best place (Q3a): the resource that ends it first, with its
  # load, hours and pieces there.
  Opcao = Struct.new(:recurso, :carga, :horas, :trechos, :fim, keyword_init: true) do
    def inicio
      trechos.first&.inicio
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

  # Its place comes once all are placed (numerar_pelo_inicio).
  def entrar_na_fila(vez)
    @filas[vez.setor] << vez
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
                                     antes: etapa.trava.filter_map { |trava| abertas[trava] }, movimento: @ordens[[ pedido.id, etapa.chave ]],
                                     fixacao: @fixacoes[[ pedido.id, etapa.chave ]], maquina_da_baixa: maquina_da_ultima(situacoes)).tap do |vez|
        vez.ordem = ordem_de(vez, indice)
      end
    end
  end

  def maquina_da_ultima(situacoes)
    situacoes.filter_map(&:baixa).select(&:maquina_id).max_by(&:created_at)&.maquina_id
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

  # Máquinas 2/5a (Q2a, decided 21/11/2026 — "ordem estrita me incomoda"):
  # no strict order, the whole factory at once. Of the stages whose ones
  # waited for are placed, the one that may start first goes, its order
  # (arrival, a move) breaking ties: a stage waiting for another holds no
  # one, and when ready takes its place ahead of the ones that came after
  # it and haven't started (a started piece is never interrupted); a
  # machine doing two sectors' trabalhos serves them by it (Q1a). The ones
  # under way start now and sort first. (The Dublagem went like this since
  # 5b1c2, Q3b; now every sector does.)
  def agendar(vezes)
    pendentes = vezes.sort_by(&:ordem)
    until pendentes.empty?
      vez = pendentes.select { |outra| outra.antes.all?(&:colocada) }.min_by { |outra| [ inicio_possivel(outra), outra.ordem ] }
      entrar_na_fila(colocar(pendentes.delete(vez), @agenda))
    end
  end

  # A sector's places (1º, 2º…): the order its pieces start in (2/5a) — the
  # one ending first may start before one placed ahead of it; none without previsão.
  def numerar_pelo_inicio
    @filas.each_value do |fila|
      previstas, sem = fila.partition(&:fim)
      previstas.each_with_index.sort_by { |vez, indice| [ vez.inicio, indice ] }.map(&:first).each.with_index(1) { |vez, posicao| vez.posicao = posicao }
      fila.replace(previstas.sort_by(&:posicao) + sem)
    end
  end

  # When it would start: one without previsão first (it takes no hours), one
  # past the horizon last.
  def inicio_possivel(vez)
    return agora - HORIZONTE if bloqueio(vez)

    opcao = opcao(vez, @agenda)
    return agora - HORIZONTE unless opcao

    opcao.inicio || agora + HORIZONTE
  end

  def pronto(vez) = ([ agora ] + vez.antes.filter_map(&:fim)).max

  # Places it after the stages it waits for (their Vez in antes), on its best resource.
  def colocar(vez, agenda)
    vez.colocada = true
    motivo, falta = bloqueio(vez)
    return vez.tap { |v| v.motivo, v.falta = motivo, falta } if motivo

    opcao = opcao(vez, agenda)
    return vez.tap { |v| v.motivo = "#{v.etapa.nome} (#{Pedido::ROTULOS_DOS_TIPOS[v.pedido.tipo]}) sem ritmo" } unless opcao

    vez.espera = vez.antes.select { |outra| outra.fim > agora }.max_by(&:fim)
    encher(vez, opcao, agenda)
  end

  # Why it can't have a previsão: [motivo, falta] — a stage it waits for has
  # none, or a missing material holds it; nil when it can.
  def bloqueio(vez)
    sem = vez.antes.find { |outra| outra.fim.nil? }
    return [ sem.motivo, sem.falta ] if sem

    [ "previsão quando #{vez.preso.map(&:nome_completo).join(" e ")} entrar", true ] if vez.preso
  end

  # The resource that ends it first (Q3a; a tie, the first registered); nil
  # without a rhythm (Q2a). The queue's own agenda keeps it until one of its
  # resources moves.
  def opcao(vez, agenda)
    ritmo = ritmo_de(vez)
    recursos = fixados(vez, @recursos.do_ritmo(ritmo, vez.setor))
    estado = recursos.map { |recurso| [ agenda.livre[recurso.chave], agenda.ultimo_material[recurso.chave] ] }
    guardada = @opcoes[vez] if agenda.equal?(@agenda)
    return guardada[1] if guardada && guardada[0] == estado

    melhor = recursos.filter_map { |recurso| opcao_em(vez, ritmo, recurso, agenda) }.min_by { |opcao| opcao.fim || agora + (2 * HORIZONTE) }
    @opcoes[vez] = [ estado, melhor ] if agenda.equal?(@agenda)
    melhor
  end

  # Held on a machine (2/5b): only it, while it is one of the stage's —
  # trashed, or no longer doing the trabalho, the piece is automatic again.
  # Started on one (4/5a, Q1a: its last baixa's), that one wins.
  def fixados(vez, recursos)
    maquina_id = vez.maquina_da_baixa || vez.fixacao&.para_maquina_id
    return recursos unless maquina_id

    recursos.select { |recurso| recurso.maquina&.id == maquina_id }.presence || recursos
  end

  def ritmo_de(vez)
    @ritmos[[ vez.pedido.tipo, vez.etapa.chave ]] || RitmoProducao.new(tipo: vez.pedido.tipo, etapa: vez.etapa.chave).tap { |ritmo| ritmo.maquinas = [] }
  end

  def opcao_em(vez, ritmo, recurso, agenda)
    carga = carga_em(vez, ritmo, recurso, agenda)
    horas = ritmo.horas(carga.valor, @medidas[[ vez.pedido.tipo, vez.etapa.chave ]], parte: recurso.parte)
    return unless horas

    trechos, fim = trechos(vez.etapa.chave, [ agenda.livre[recurso.chave], pronto(vez) ].max, horas)
    Opcao.new(recurso: recurso, carga: carga, horas: horas, trechos: fim ? trechos : [], fim: fim)
  end

  # Its load there: the same on every resource, but a cutting machine's
  # time is its own, from the material it ended on (Q8a).
  def carga_em(vez, ritmo, recurso, agenda)
    corte = ritmo.maquina_de_corte?
    anterior = agenda.ultimo_material[recurso.chave] if corte
    fonte = recurso.trabalho if corte
    @cargas[[ vez.object_id, fonte&.id, anterior&.id ]] ||=
      CargaDaEtapa.call(vez.pedido, vez.etapa, vez.linhas, ritmo, anterior: anterior, memoria: @memoria, fonte: fonte)
  end

  def encher(vez, opcao, agenda)
    vez.carga, vez.horas, vez.sem_medida = opcao.carga.valor, opcao.horas, opcao.carga.sem_medida
    vez.recurso, vez.maquina = opcao.recurso.chave, opcao.recurso.maquina
    vez.trechos, vez.fim = opcao.trechos, opcao.fim
    vez.inicio = vez.trechos.first&.inicio
    agenda.livre[vez.recurso] = vez.fim || agora + HORIZONTE
    agenda.ultimo_material[vez.recurso] = opcao.carga.ultimo_material if opcao.carga.ultimo_material
    vez.motivo = ocorrencias.empty? ? "sem turnos cadastrados" : "a fila passa de 90 dias" unless vez.fim
    vez
  end

  def pecas_de(vezes)
    vezes.flat_map { |vez| vez.trechos.map { |trecho| [ vez, trecho ] } }
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
