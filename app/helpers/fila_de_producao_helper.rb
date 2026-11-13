# How the Painel says the queue (Painel 2/4b): the previsão, the folga chip
# approved in the Fila A mockup, a moment in the queue, a stage's load. A
# cliente final sees days only, never a material's name (Q4a).
module FilaDeProducaoHelper
  # The folga chip: green from 2 days, orange on the day or 1 day, red late.
  # Usage: selo_da_folga(-2) # => <span class="painel-folga painel-folga--atrasa">atrasa 2 dias</span>
  def selo_da_folga(folga)
    return if folga.nil?

    texto, nivel = if folga.negative? then [ "atrasa #{pluralize(-folga, "dia", plural: "dias")}", "atrasa" ]
    elsif folga.zero? then [ "vence no dia", "justa" ]
    else [ "folga #{pluralize(folga, "dia", plural: "dias")}", folga == 1 ? "justa" : "ok" ]
    end
    tag.span(texto, class: "painel-folga painel-folga--#{nivel}", data: { folga: folga })
  end

  # What a stage asks in its queue: its open lines of the total — a
  # dublagem's are letras, each named with the pedido, the piece's label at
  # the machine (5b1c2, Q4: "#7674gj44|DUB-A"); started, the ones left.
  # Usage: o_que_fazer_na_fila(vez) # => "1 de 3 letras · Dublagem: falta #7674gj44|DUB-C", "8 linhas · Corte"
  def o_que_fazer_na_fila(vez)
    letras = vez.linhas.filter_map { |linha| linha.dublagem&.letra }
    palavra = letras.any? && letras.size == vez.linhas.size ? "letra" : "linha"
    # 5b1c3 (Q3a): not started, it counts the letras it goes with — the free ones.
    quantas = vez.iniciada? ? "#{vez.abertas} de #{vez.total} #{palavra.pluralize(vez.total)}" : pluralize(vez.linhas.size, palavra)
    return "#{quantas} · #{vez.etapa.nome}" unless palavra == "letra"

    codigos = letras.tally.map { |letra, vezes| tag.span("##{vez.pedido.uuid.first(8)}|#{letra}#{" ×#{vezes}" if vezes > 1}", class: "painel-fila-letra", data: { letra: letra }) }
    safe_join([ "#{quantas} · #{vez.etapa.nome}: #{"falta " if vez.iniciada?}", safe_join(codigos, ", ") ])
  end

  # The letras a missing material holds out of the stage's queue (5b1c3,
  # Q3a); nil when none. A cliente final sees no queue.
  # Usage: aviso_das_retidas(vez) # => "DUB-B, DUB-C aguardam Espuma TC4 Branco-1.40 m"
  def aviso_das_retidas(vez)
    return if vez.retidas.blank?

    letras = vez.retidas.map { |linha| linha.dublagem.letra }.uniq
    "#{letras.join(", ")} #{letras.one? ? "aguarda" : "aguardam"} #{vez.retidas_por.map(&:nome_completo).join(" e ")}"
  end

  # Usage: momento_da_fila(Time.zone.parse("2026-11-12 15:30")) # => "qui 12/11 15:30" ("hoje 15:30", "amanhã 09:00")
  def momento_da_fila(momento)
    data = momento.to_date
    dia = { Date.current => "hoje", Date.current + 1 => "amanhã" }.fetch(data) { dia_com_semana(data) }
    cliente_final? ? dia : "#{dia} #{momento.strftime("%H:%M")}"
  end

  # Usage: texto_da_previsao(linha.previsao) # => "qui 12/11 15:30", "se confirmar agora: amanhã 09:00"
  def texto_da_previsao(previsao)
    return "—" if previsao.nil?
    return "pronto p/ entregar" if previsao.pronta?
    return motivo_da_previsao(previsao) unless previsao.fim

    "#{"se confirmar agora: " if previsao.se_confirmar}#{momento_da_fila(previsao.fim)}"
  end

  # Why there is no previsão.
  def motivo_da_previsao(previsao)
    vez = previsao.vezes.find { |outra| outra.fim.nil? }
    vez ? motivo_da_vez(vez) : previsao.motivo
  end

  # A cliente final is told a material is missing, not which.
  def motivo_da_vez(vez)
    return vez.motivo unless cliente_final?

    vez.falta ? "previsão quando o material entrar" : "sem previsão"
  end

  # A stage's time on the path: "hoje 08:00 → 11:30", or why it has none.
  def periodo_da_vez(vez)
    return motivo_da_vez(vez) unless vez.fim

    "#{momento_da_fila(vez.inicio)} → #{vez.fim.to_date == vez.inicio.to_date && !cliente_final? ? vez.fim.strftime("%H:%M") : momento_da_fila(vez.fim)}"
  end

  # What a stage of a pedido weighs, in its rhythm's unit.
  # Usage: carga_da_vez(vez) # => "12,5 m", "180 peças", "8,2 m de papel", "1,4 h de máquina"
  def carga_da_vez(vez)
    unidade = { "papel" => "m de papel", "maquina_de_corte" => "h de máquina" }.fetch(vez.etapa.ritmo.to_s) { vez.etapa.unidade_da_medida }
    "#{numero_br(vez.carga, 1)} #{unidade}"
  end

  # "2,5 h", "40 min".
  def horas_da_fila(horas)
    horas < 1 ? "#{(horas * 60).round} min" : "#{numero_br(horas, 1)} h"
  end

  # When the Painel next refreshes by itself: the next turno to start or
  # end (Q5a), as ms since the epoch; nil without turnos ahead.
  def proxima_virada(fila)
    agora = fila.agora
    momento = fila.ocorrencias.flat_map { |o| [ o.inicio, o.fim ] }.select { |m| m > agora }.min
    momento && (momento.to_f * 1000).round
  end
end
