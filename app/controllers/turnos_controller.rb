# The factory's turnos and calendar (Painel 2/4a, decided 05/11/2026), the
# dono's like the rest of Parâmetros: the turnos (name, hours, days), the
# year's exceptions and the national holidays it suggests (Q9a). What the
# queue and the previsão run on (2/4b). Máquinas 3/5a: the stops with their
# period, machines, impact and "voltou a funcionar".
class TurnosController < ApplicationController
  exige_dono

  # Usage: GET /parametros/turnos(?ano=2027)
  def index
    @ano = (params[:ano].presence || Date.current.year).to_i
    @turnos = visiveis(Turno).ativos.order(:inicio_min)
    @excecoes = visiveis(ExcecaoCalendario).do_ano(@ano).includes(:turno, :user, :voltou_por, paradas_das_maquinas: { maquina: :trabalhos }).order(:data)
    @feriados_confirmados = @excecoes.select { |excecao| excecao.origem == "feriado" }.index_by(&:data)
    preparar_paradas
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

  # Máquinas 3/5a: the stage's machines for the new stop's window, the stop
  # just saved (its warning) and the pedidos its impact names.
  def preparar_paradas
    @maquinas_por_etapa = ExcecaoCalendario.etapas.keys.index_with { |etapa| maquinas_da_etapa(etapa) }.compact_blank
    @parada_salva = visiveis(ExcecaoCalendario).find_by(uuid: flash[:parada_salva]) if flash[:parada_salva]
    uuids = (@excecoes.to_a + [ @parada_salva ]).compact.flat_map { |parada| Array(parada.impacto&.dig("pedidos")).pluck("pedido_uuid") }
    @pedidos_do_impacto = visiveis(Pedido).where(uuid: uuids).includes(:client).index_by(&:uuid)
  end

  def maquinas_da_etapa(etapa)
    @maquinas ||= visiveis(Maquina).ativos.includes(:trabalhos).order(:id).to_a
    trabalhos = ExcecaoCalendario.trabalhos_da_etapa(etapa)
    @maquinas.select { |maquina| maquina.trabalhos.any? { |feito| trabalhos.include?(feito.trabalho) } }
  end

  def dados_do_turno
    params.require(:turno).permit(:nome, :inicio, :fim, dias: []).tap { |dados| dados[:nome] = dados[:nome].to_s.strip if dados.key?(:nome) }
  end

  def responder(salvou, turno, aviso)
    mensagem = salvou ? { notice: aviso } : { alert: turno.errors.full_messages.to_sentence }
    redirect_to parametros_turnos_path, **mensagem
  end
end
