# How the Painel says the programação (Painel 3/4a): the impact window's
# title, a previsão in it, and each line of a pedido's "Histórico da
# programação" (the team's only). Painel 3/4b: a virada in that history,
# the "veio de · adiada" mark, a turno's load over 100%. Painel 3/4b2: the
# faixa's plans and "quem cruzou".
module ProgramacaoHelper
  # Usage: titulo_do_impacto(impacto) # => "#c210aa12 · Impressão: 3º → 1º"
  def titulo_do_impacto(impacto)
    return "Fila da #{LinhaDoPainel::COLUNAS.fetch(impacto.setor)}: voltar tudo à ordem de chegada (#{pluralize(impacto.movimentos.size, "movida", plural: "movidas")})" if impacto.tipo == :setor

    vez = impacto.vez
    nome = "##{vez.pedido.uuid.first(8)} · #{vez.etapa.nome}"
    return "#{nome}: voltar à ordem de chegada (#{impacto.de}º → #{impacto.para}º)" if impacto.tipo == :chegada

    "#{nome}: #{impacto.de}º → #{impacto.para}º"
  end

  # Usage: previsao_do_impacto(nil) # => "sem previsão"
  def previsao_do_impacto(momento)
    momento ? momento_da_fila(momento) : "sem previsão"
  end

  # A movement as the pedido's history says it: its own, or the one that pushed it.
  # A virada (ViradaDoPedido) too.
  # Usage: linha_do_historico(movimento, pedido)
  #        # => "05/11 14:20 · Dione passou o #c210aa12 à frente na Impressão (3º → 1º) · cliente pediu urgência · este pedido: qui 12/11 15:30 → sex 13/11 09:00"
  def linha_do_historico(movimento, pedido)
    return linha_da_virada(movimento) if movimento.is_a?(ViradaDoPedido)

    partes = [ "#{movimento.created_at.strftime("%d/%m %H:%M")} · #{movimento.user.nome} #{acao_do_movimento(movimento)}", movimento.motivo.presence ]
    partes << efeito_do_movimento(movimento, pedido)
    partes.compact.join(" · ")
  end

  # Usage: linha_da_virada(virada)
  #        # => "06/11 13:02 · virada para a Tarde · não terminaram na Manhã: Impressão do #c210aa12 · este pedido: qui 12/11 15:30 → sex 13/11 09:00 · passou a atrasar"
  def linha_da_virada(virada)
    partes = [ "#{virada.created_at.strftime("%d/%m %H:%M")} · virada para a #{virada.turno_nome}", causa_da_virada(virada.nao_terminaram) ]
    partes << "este pedido: #{momento_da_fila(virada.de)} → #{previsao_do_impacto(virada.para)}"
    partes << "passou a atrasar" if virada.passou_a_atrasar
    partes.join(" · ")
  end

  # The pedido's movements and viradas by time, read once per page (the Painel gives them all).
  def historico_da_programacao(pedido)
    @historicos ||= {}
    @historicos[pedido.id] ||= (visiveis(MovimentoDaFila).do_pedido(pedido).to_a + visiveis(ViradaDoPedido).where(pedido: pedido).to_a).sort_by(&:created_at)
  end

  # Q3a: "veio de hoje · Manhã · adiada 2 turnos" — a stage the photo had end
  # in a turno already over, still open. nil when it ran as programmed.
  # Usage: texto_do_adiamento(programado.adiamento(vez))
  def texto_do_adiamento(adiamento)
    return unless adiamento

    dia = { Date.current => "hoje", Date.current - 1 => "ontem" }.fetch(adiamento.veio_em) { dia_com_semana(adiamento.veio_em) }
    [ "veio de #{dia} · #{adiamento.veio_de}", ("adiada #{adiamento.turnos} turnos" if adiamento.turnos > 1) ].compact.join(" · ")
  end

  # The marks of a pedido's stages in a column of the grid (the cell's detail).
  # Usage: adiamento_da_coluna(linha, "estamparia") # => "Calandra: veio de ontem · Tarde"
  def adiamento_da_coluna(linha, coluna)
    return if @programado.nil? || linha.previsao.nil? || linha.previsao.se_confirmar

    marcas = linha.previsao.vezes.select { |vez| vez.setor == coluna }.filter_map do |vez|
      texto = texto_do_adiamento(@programado.adiamento(vez))
      "#{vez.etapa.nome}: #{texto}" if texto
    end
    marcas.join("; ").presence
  end

  # The pedido's first plan per stage, read once by the Painel (none for a cliente final).
  # Usage: planos_da_faixa(pedido)["impressao"].fim
  def planos_da_faixa(pedido)
    (@planos || {}).fetch(pedido.id, []).index_by(&:etapa)
  end

  # Usage: cruzamentos_da_faixa(pedido).size # => 3
  def cruzamentos_da_faixa(pedido)
    (@cruzamentos || {}).fetch(pedido.id, [])
  end

  # Q9a: why a pedido crossed this one, one line per crossing, by time
  # (its lane's tip in the faixa's timeline).
  # Usage: causas_da_cruzada(cruzada)
  #        # => "empurrou este pedido · 05/11 · Dione passou o #c210aa12 à frente na Impressão (2º → 1º) · urgente"
  def causas_da_cruzada(cruzada)
    cruzada.cruzamentos.map do |cruzamento|
      quem = cruzamento.papel == :empurrou ? "empurrou este pedido" : "foi empurrado por este pedido"
      [ quem, cruzamento.quando.strftime("%d/%m"), causa_do_cruzamento(cruzamento) ].join(" · ")
    end.join("\n")
  end

  CargaDoTurno = Struct.new(:ocupadas, :percentual, :estourou, keyword_init: true)

  # A turno's load in its sector's queue: what the queue fills there, or what
  # its photo programmed and is still to do, when more (Q7a) — past the hours
  # left, over 100%.
  # Usage: carga_do_turno(turno, "impressao").percentual # => 130
  def carga_do_turno(turno, setor)
    pendentes = @programado&.pendentes_do_turno(setor, turno.ocorrencia) || 0
    ocupadas = [ turno.ocupadas, pendentes ].max
    return CargaDoTurno.new(ocupadas: ocupadas, percentual: 100, estourou: pendentes.positive?) unless turno.livres.positive?

    estourou = pendentes > turno.livres + 0.01
    percentual = (ocupadas / turno.livres * 100).round
    CargaDoTurno.new(ocupadas: ocupadas, percentual: estourou ? percentual : [ percentual, 100 ].min, estourou: estourou)
  end

  private

  def causa_da_virada(nao_terminaram)
    return "a fila mudou desde o turno anterior" if nao_terminaram.empty?

    "não terminaram na #{nao_terminaram.first["veio_de"]}: #{nao_terminaram.map { |e| "#{e["etapa"]} do ##{e["pedido"].first(8)}" }.join(", ")}"
  end

  def causa_do_cruzamento(cruzamento)
    if (movimento = cruzamento.movimento)
      return [ "#{movimento.user.nome} #{acao_do_movimento(movimento)}", movimento.motivo.presence ].compact.join(" · ")
    end

    turno = cruzamento.virada.nao_terminaram.first["veio_de"]
    cruzamento.papel == :empurrou ? "a #{cruzamento.etapa} dele não terminou na #{turno}" : "a #{cruzamento.etapa} deste não terminou na #{turno}"
  end

  def acao_do_movimento(movimento)
    etapa = EtapasProducao.etapa(movimento.pedido.tipo, movimento.etapa, pedido: movimento.pedido).nome
    numero = "##{movimento.pedido.uuid.first(8)}"
    return "voltou o #{numero} à ordem de chegada na #{etapa}" if movimento.voltou?

    "#{movimento.para < movimento.de ? "passou o #{numero} à frente" : "pôs o #{numero} mais atrás"} na #{etapa} (#{movimento.de}º → #{movimento.para}º)"
  end

  def efeito_do_movimento(movimento, pedido)
    if movimento.pedido_id == pedido.id
      return if movimento.voltou? || movimento.para > movimento.de

      "passou à frente de #{pluralize(movimento.de - movimento.para, "pedido", plural: "pedidos")}"
    elsif (empurrado = movimento.empurrado(pedido))
      para = empurrado["para"] ? momento_da_fila(Time.zone.parse(empurrado["para"])) : "sem previsão"
      "este pedido: #{momento_da_fila(Time.zone.parse(empurrado["de"]))} → #{para}"
    end
  end
end
