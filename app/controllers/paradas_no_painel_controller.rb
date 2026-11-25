# The ⏸ on a machine's lane (Máquinas 3/5b, decided 24/11/2026, canvas
# "Máquinas", 7–8): the new stop's window inside the Painel, the stage and
# the machine picked, today to today, saying before saving which other
# stages it stops too (Q1a) and how many pieces wait for it (Q2a); saved,
# the same warning as on the Turnos page (Q3a), and the Painel refreshes.
# Who programs the production (Q5a).
class ParadasNoPainelController < ApplicationController
  exige :pedidos, :ver
  exige_acao :programar_producao
  layout false

  # Usage: GET /painel/paradas/nova?maquina=<uuid>&setor=estamparia
  def new
    maquina = visiveis(Maquina).ativos.includes(:trabalhos).por_uuid!(params[:maquina])
    etapa = ExcecaoCalendario.etapa_da_maquina(maquina, params[:setor].to_s)
    parada = ExcecaoCalendario.new(data: Date.current, data_fim: Date.current, etapa: etapa)
    render partial: "paineis/nova_parada", locals: { parada: parada, maquina: maquina, setor: params[:setor], esperam: esperam(maquina), erro: nil }
  end

  # Usage: POST /painel/paradas (excecao[nome|data|data_fim|turno_uuid|etapa|maquina_uuids][], maquina, setor)
  def create
    maquina = visiveis(Maquina).ativos.includes(:trabalhos).por_uuid!(params[:maquina])
    resultado = SalvarParada.call(dados_da_parada, fila: fila_agora, maquinas: visiveis(Maquina), user: Current.user)
    return recusar(resultado, maquina) if resultado.erro

    parada = resultado.parada
    @pedidos_do_impacto = visiveis(Pedido).where(uuid: Array(parada.impacto["pedidos"]).pluck("pedido_uuid")).includes(:client).index_by(&:uuid)
    render partial: "paineis/parada_feita", locals: { parada: parada }
  end

  private

  def dados_da_parada
    params.require(:excecao).permit(:nome, :data, :data_fim, :turno_uuid, :etapa, maquina_uuids: [])
  end

  def fila_agora
    @fila_agora ||= begin
      movimentos = visiveis(MovimentoDaFila)
      FilaDeProducao.call(calendario: calendario_de_producao, ordens: movimentos.ordens, fixacoes: movimentos.fixacoes)
    end
  end

  # The pieces that can't leave it (Q2a): { presa: 1, comecada: 1 }.
  def esperam(maquina)
    vezes = fila_agora.pedidos.flat_map { |pedido| fila_agora.previsao(pedido).vezes }.select { |vez| vez.maquina&.id == maquina.id }
    { comecada: vezes.count { |vez| vez.maquina_da_baixa == maquina.id }, presa: vezes.count { |vez| vez.maquina_da_baixa != maquina.id && vez.fixacao&.para_maquina_id == maquina.id } }
  end

  def recusar(resultado, maquina)
    render partial: "paineis/nova_parada", status: :unprocessable_content,
           locals: { parada: resultado.parada, maquina: maquina, setor: params[:setor], esperam: esperam(maquina), erro: resultado.erro }
  end
end
