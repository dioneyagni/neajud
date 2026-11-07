# How the Linha do tempo (Painel 2/4c) says a bar, a day's load and its
# window. A cliente final sees days only (Q4a).
module LinhaDoTempoHelper
  CARGA_EM_TEXTO = { passado: "·", sem_turno: "", parada: "parada", encerrado: "encerrado", livre: "livre", cheio: "cheio" }.freeze

  # Usage: estilo_do_pedaco([ 12.5, 30 ]) # => "left: 12.5%; width: 30%"
  def estilo_do_pedaco(pedaco)
    "left: #{pedaco[0]}%; width: #{pedaco[1]}%"
  end

  # What the bar's end says.
  # Usage: rotulo_da_barra(barra) # => "sex 13/11 · atrasa 2 dias", "entregue 05/11", "se confirmar agora: qui 12/11"
  def rotulo_da_barra(barra)
    case barra.grupo
    when "entregues" then "entregue #{barra.fim.strftime("%d/%m")}"
    when "sem_previsao" then motivo_da_previsao(barra.sem_previsao)
    when "pendentes" then barra.fim ? "se confirmar agora: #{dia_com_semana(barra.fim.to_date)}" : motivo_da_previsao(barra.sem_previsao)
    else rotulo_da_previsao(barra)
    end
  end

  # A bar that started before the window says when.
  # Usage: comeco_da_barra(barra) # => "‹ começou sex 30/10"
  def comeco_da_barra(barra)
    "‹ começou #{dia_com_semana(barra.inicio.to_date)}" if barra.comecou_antes?
  end

  # Usage: texto_da_carga(celula) # => "64%", "cheio", "parada"
  def texto_da_carga(celula)
    CARGA_EM_TEXTO.fetch(celula.estado) { "#{celula.percentual}%" }
  end

  # Usage: dica_da_carga("Corte", celula) # => "Corte · qui 12/11 · 64% das horas de turno"
  def dica_da_carga(nome, celula)
    detalhe = case celula.estado
    when :passado then "passado: só o registro"
    when :sem_turno then "sem turno"
    when :parada then "a etapa para neste dia"
    when :encerrado then "os turnos de hoje acabaram"
    else "#{celula.percentual}% das horas de turno#{" que restam hoje" if celula.data == Date.current}"
    end
    "#{nome} · #{dia_com_semana(celula.data)} · #{detalhe}"
  end

  # Usage: periodo_da_janela(tempo) # => "sex 05/11 – qui 18/11"
  def periodo_da_janela(tempo)
    "#{dia_com_semana(tempo.de)} – #{dia_com_semana(tempo.ate - 1)}"
  end

  # The Painel's address with the Linha do tempo's window and order.
  # Usage: painel_no_tempo(de: Date.current + 12, ordem: "prazo")
  def painel_no_tempo(de:, ordem:)
    painel_path({ visao: "tempo", de: de.iso8601, ordem: (ordem unless ordem == "chegada"), entregues: params[:entregues] }.compact)
  end

  private

  def rotulo_da_previsao(barra)
    return "pronto p/ entregar" if barra.pronta?

    atraso = barra.dias_de_atraso
    "#{dia_com_semana(barra.fim.to_date)}#{" · atrasa #{pluralize(atraso, "dia", plural: "dias")}" if atraso}"
  end
end
