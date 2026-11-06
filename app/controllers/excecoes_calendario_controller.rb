# The calendar's exceptions (Painel 2/4a, decided 05/11/2026, Q8a): a day or
# a turno the whole factory, or one stage, doesn't work; and the national
# holidays the dono confirms (Q9a). Shown on the Turnos page.
class ExcecoesCalendarioController < ApplicationController
  exige_dono

  # Usage: POST /parametros/excecoes (excecao[nome|data|turno_uuid|etapa])
  def create
    excecao = visiveis(ExcecaoCalendario).new(params.require(:excecao).permit(:nome, :data, :turno_uuid, :etapa).merge(origem: "manual"))
    return voltar(excecao.data, notice: "#{excecao.nome} (#{I18n.l(excecao.data, format: "%d/%m/%Y")}) saved.") if excecao.save

    voltar(excecao.data, alert: excecao.errors.full_messages.to_sentence)
  rescue ActiveRecord::RecordNotFound
    voltar(nil, alert: "Turno #{params.dig(:excecao, :turno_uuid).inspect} not found; expected one of the turnos listed")
  end

  def destroy
    excecao = visiveis(ExcecaoCalendario).por_uuid!(params[:uuid])
    excecao.destroy!
    voltar(excecao.data, notice: "#{excecao.nome} (#{I18n.l(excecao.data, format: "%d/%m/%Y")}) removed.")
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

  def voltar(data, **mensagem)
    redirect_to parametros_turnos_path(ano: data&.year, anchor: "calendario"), **mensagem
  end
end
