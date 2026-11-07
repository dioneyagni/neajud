# Moving a stage in its sector's queue (Painel 3/4a, decided 07/11/2026):
# the impact window, then the confirmation. Only who programs the
# production (programar_producao, a team action).
class MovimentosDaFilaController < ApplicationController
  exige :pedidos, :ver
  exige_acao :programar_producao
  layout false

  # The window: what the move does, before anyone confirms it.
  # Usage: GET /painel/fila/impacto?pedido=<uuid>&etapa=impressao&posicao=1
  #        GET /painel/fila/impacto?pedido=<uuid>&etapa=impressao     (back to its arrival)
  #        GET /painel/fila/impacto?setor=impressao                     (every moved one back)
  def impacto
    render partial: "paineis/impacto", locals: { impacto: calcular, erro: nil, motivo: nil }
  rescue ImpactoDoMovimento::Invalido => e
    render partial: "paineis/impacto_invalido", locals: { erro: e.message }, status: :unprocessable_content
  end

  # Usage: POST /painel/fila/movimentos (the same params, and motivo)
  def create
    impacto = calcular
    MoverNaFila.call(impacto, user: Current.user, motivo: params[:motivo])
    render partial: "paineis/impacto_feito", locals: { impacto: impacto }
  rescue MoverNaFila::SemMotivo => e
    render partial: "paineis/impacto", locals: { impacto: impacto, erro: e.message, motivo: params[:motivo] }, status: :unprocessable_content
  rescue ImpactoDoMovimento::Invalido => e
    render partial: "paineis/impacto_invalido", locals: { erro: e.message }, status: :unprocessable_content
  end

  private

  # The queue reads the whole factory (FilaDeProducao); the pedido moved is a visible one.
  def calcular
    pedido = visiveis(Pedido).por_uuid!(params[:pedido]) if params[:pedido].present?
    ImpactoDoMovimento.call(FilaDeProducao.call(ordens: visiveis(MovimentoDaFila).ordens), pedido: pedido, etapa: params[:etapa].presence,
                            posicao: params[:posicao].presence&.to_i, setor: params[:setor].presence)
  end
end
