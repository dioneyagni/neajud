# The factory's turnos and calendar (Painel 2/4a, decided 05/11/2026), the
# dono's like the rest of Parâmetros: the turnos (name, hours, days), the
# year's exceptions and the national holidays it suggests (Q9a). What the
# queue and the previsão run on (2/4b).
class TurnosController < ApplicationController
  exige_dono

  # Usage: GET /parametros/turnos(?ano=2027)
  def index
    @ano = (params[:ano].presence || Date.current.year).to_i
    @turnos = visiveis(Turno).ativos.order(:inicio_min)
    @excecoes = visiveis(ExcecaoCalendario).do_ano(@ano).includes(:turno).order(:data)
    @feriados_confirmados = @excecoes.select { |excecao| excecao.origem == "feriado" }.index_by(&:data)
  end

  # Usage: POST /parametros/turnos (turno[nome|inicio|fim|dias][])
  def create
    turno = visiveis(Turno).new(dados_do_turno)
    responder(turno.save, turno, "Turno #{turno.nome} saved.")
  end

  def update
    turno = visiveis(Turno).ativos.por_uuid!(params[:uuid])
    responder(turno.update(dados_do_turno), turno, "Turno #{turno.nome} saved.")
  end

  def destroy
    turno = visiveis(Turno).ativos.por_uuid!(params[:uuid])
    turno.excluir!(**autoria)
    redirect_to parametros_turnos_path, notice: "Turno #{turno.nome} moved to the trash."
  end

  private

  def dados_do_turno
    params.require(:turno).permit(:nome, :inicio, :fim, dias: []).tap { |dados| dados[:nome] = dados[:nome].to_s.strip if dados.key?(:nome) }
  end

  def responder(salvou, turno, aviso)
    mensagem = salvou ? { notice: aviso } : { alert: turno.errors.full_messages.to_sentence }
    redirect_to parametros_turnos_path, **mensagem
  end
end
