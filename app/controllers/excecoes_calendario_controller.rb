# The calendar's exceptions (Painel 2/4a, decided 05/11/2026, Q8a): a day or
# a turno the whole factory, or one stage, doesn't work; and the national
# holidays the dono confirms (Q9a). Shown on the Turnos page.
#
# Máquinas 3/5a (decided 24/11/2026): a stop runs de…até and may take some
# of its stage's machines; saved with no confirmation, what it does to the
# queue kept with it and shown (Q3a, Q4a); "voltou a funcionar" ends it
# from now on (Q7a). Who programs the production creates and ends stops
# (Q5a); removing one made by mistake and the holidays stay the dono's.
class ExcecoesCalendarioController < ApplicationController
  exige_acao :programar_producao, only: %i[create voltou]
  exige_dono only: %i[destroy feriado]

  # Usage: POST /parametros/excecoes (excecao[nome|data|data_fim|turno_uuid|etapa|maquina_uuids][])
  def create
    resultado = SalvarParada.call(dados_da_parada, fila: fila_agora, maquinas: visiveis(Maquina), user: Current.user)
    parada = resultado.parada
    return voltar(parada.data, alert: resultado.erro) if resultado.erro

    flash[:parada_salva] = parada.uuid
    voltar(parada.data, notice: "#{parada.nome} (#{periodo_da_parada(parada)}) salva.")
  rescue ActiveRecord::RecordNotFound => e
    voltar(nil, alert: e.message.start_with?("Machine") ? e.message : "Turno #{params.dig(:excecao, :turno_uuid).inspect} not found; expected one of the turnos listed")
  end

  # Came back to work (Q7a): it stops no more from now on; when and who stay.
  # Usage: PATCH /parametros/excecoes/:uuid/voltou
  def voltou
    parada = visiveis(ExcecaoCalendario).por_uuid!(params[:uuid])
    return voltar(parada.data, alert: "#{parada.nome} #{parada.voltou_em ? "already came back to work" : "has not started"}; expected a stop under way") unless parada.em_andamento?

    parada.update!(voltou_em: Time.current, voltou_por: Current.user)
    voltar(parada.data, notice: "#{parada.nome}: voltou a funcionar.")
  end

  # Only one made by mistake: a stop that ended stays on the record.
  def destroy
    excecao = visiveis(ExcecaoCalendario).por_uuid!(params[:uuid])
    return voltar(excecao.data, alert: "#{excecao.nome} ended: it stays on the record") if excecao.encerrada?

    excecao.destroy!
    voltar(excecao.data, notice: "#{excecao.nome} (#{periodo_da_parada(excecao)}) removed.")
  end

  # Confirms (or, confirmado=0, takes back) a suggested national holiday.
  # Usage: POST /parametros/excecoes/feriado (data=2026-11-20, confirmado=1)
  def feriado
    @excecoes = visiveis(ExcecaoCalendario)
    data = Date.iso8601(params[:data].to_s)
    sugerido = FeriadosNacionais.do_ano(data.year).find { |f| f.data == data }
    return voltar(data, alert: "#{data.strftime("%d/%m/%Y")} is not a national holiday; expected one of the suggested days") unless sugerido

    confirmar_feriado(sugerido, params[:confirmado] == "1")
  rescue Date::Error
    voltar(nil, alert: "Date #{params[:data].inspect} is not a date like 2026-11-20")
  end

  private

  def dados_da_parada
    params.require(:excecao).permit(:nome, :data, :data_fim, :turno_uuid, :etapa, maquina_uuids: [])
  end

  # The queue now, as who saves sees it: what the stop is compared with.
  def fila_agora
    movimentos = visiveis(MovimentoDaFila)
    FilaDeProducao.call(calendario: calendario_de_producao, ordens: movimentos.ordens, fixacoes: movimentos.fixacoes)
  end

  def periodo_da_parada(parada)
    inicio = I18n.l(parada.data, format: "%d/%m/%Y")
    parada.data_fim.nil? || parada.data_fim == parada.data ? inicio : "#{inicio} – #{I18n.l(parada.data_fim, format: "%d/%m/%Y")}"
  end

  def confirmar_feriado(sugerido, confirmar)
    existente = @excecoes.find_by(origem: "feriado", data: sugerido.data)
    if confirmar
      @excecoes.create!(data: sugerido.data, nome: sugerido.nome, origem: "feriado") unless existente
      voltar(sugerido.data, notice: "#{sugerido.nome}: the factory stops on #{I18n.l(sugerido.data, format: "%d/%m")}.")
    else
      existente&.destroy!
      voltar(sugerido.data, notice: "#{sugerido.nome}: the factory works on #{I18n.l(sugerido.data, format: "%d/%m")}.")
    end
  end

  # The Turnos page is the dono's; who only programs the production goes
  # back to the Painel, and so does a stop ended from its lane (3/5b, painel=1).
  def voltar(data, **mensagem)
    return redirect_to painel_path, **mensagem if params[:painel].present? || !dono?

    redirect_to parametros_turnos_path(ano: data&.year, anchor: "calendario"), **mensagem
  end
end
