# The baixa of a production stage, from the Impressão, Corte, Estamparia and
# Conferência pages (Etapa 2.2, 2/3). JSON for the baixa Stimulus controller:
# ok (the page reloads and shows the flash), aviso (outside the dono's band:
# correct or confirm) or error.
#
# Usage: POST /pedidos/:pedido_uuid/baixas (etapa, nivel, alvo, medida, confirmar)
class BaixasProducaoController < ApplicationController
  exige_acao :atualizar_producao
  before_action :set_pedido

  def create
    resultado = RegistrarBaixaService.call(@pedido, etapa: params[:etapa], nivel: params[:nivel], alvo: params[:alvo],
                                                    medida: params[:medida], confirmar: params[:confirmar] == "1", **autoria)
    responder(resultado)
  rescue EtapasProducao::Invalida => e
    render json: { ok: false, error: e.message }, status: :unprocessable_content
  end

  private

  def responder(resultado)
    case resultado.estado
    when :ok
      flash[:notice] = "Baixa de #{EtapasProducao.etapa(@pedido.tipo, params[:etapa]).nome} registrada (#{resultado.baixa.linhas.size} #{resultado.baixa.linhas.one? ? "linha" : "linhas"})."
      render json: { ok: true }
    when :aviso then render json: { ok: false, aviso: resultado.mensagem }
    else render json: { ok: false, error: resultado.mensagem }, status: :unprocessable_content
    end
  end

  def set_pedido
    @pedido = Pedido.por_uuid!(params[:pedido_uuid])
  end
end
