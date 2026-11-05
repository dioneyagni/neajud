# The baixa of a production stage, from the Impressão, Corte, Estamparia and
# Conferência pages (Etapa 2.2, 2/3). JSON for the baixa Stimulus controller:
# ok (the page reloads and shows the flash), aviso (outside the dono's band:
# correct or confirm), falta_material (the entry to launch with it, decided
# 05/11/2026) or error. Undoing one (3/3) goes back to the page.
#
# Usage: POST /pedidos/:pedido_uuid/baixas (etapa, nivel, alvo, medida, confirmar; medidas[<material uuid>] — Etapa 2.3e;
#        entradas[<material uuid>:<client uuid|empresa>], autorizador[email], autorizador[senha] — the material missing)
#        DELETE /pedidos/:pedido_uuid/baixas/:uuid
class BaixasProducaoController < ApplicationController
  exige_acao :atualizar_producao
  before_action :set_pedido
  # Someone else's password checked here: the sign-in's limit (SessionsController).
  rate_limit to: 10, within: 3.minutes, only: :create, name: "autorizador", if: -> { params.dig(:autorizador, :senha).present? },
             with: -> { render json: { ok: false, error: "Too many password attempts; try again in a few minutes." }, status: :too_many_requests }

  def create
    resultado = RegistrarBaixaService.call(@pedido, etapa: params[:etapa], nivel: params[:nivel], alvo: params[:alvo],
                                                    medida: params[:medida], confirmar: params[:confirmar] == "1",
                                                    contagens: params[:contagens]&.to_unsafe_h, refazer: params[:refazer]&.to_unsafe_h,
                                                    medidas: params[:medidas]&.to_unsafe_h, entradas: params[:entradas]&.to_unsafe_h,
                                                    autorizador: params[:autorizador]&.permit(:email, :senha)&.to_h, **autoria)
    responder(resultado)
  rescue EtapasProducao::Invalida => e
    render json: { ok: false, error: e.message }, status: :unprocessable_content
  end

  def destroy
    baixa = @pedido.baixas_producao.por_uuid!(params[:id])
    erro = DesfazerBaixaService.call(baixa, user: Current.user)
    voltar = url_from(request.referer) || resumo_pedido_path(@pedido)
    return redirect_to voltar, alert: "Could not undo the baixa: #{erro}" if erro

    redirect_to voltar, notice: "Baixa de #{EtapasProducao.etapa(@pedido.tipo, baixa.etapa).nome} desfeita (#{baixa.linhas.size} #{baixa.linhas.one? ? "linha" : "linhas"} em aberto de novo)."
  end

  private

  def responder(resultado)
    case resultado.estado
    when :ok
      flash[:notice] = aviso_de_registro(resultado.baixa)
      render json: { ok: true }
    when :aviso then render json: { ok: false, aviso: resultado.mensagem }
    when :falta_material then render json: { ok: false, falta_material: resultado.mensagem, faltas: faltas_de_material(resultado),
                                             pode_lancar: pode?(:estoque, :editar) }
    when :contar then render json: { ok: false, contar: resultado.mensagem, linhas: linhas_para_contar(resultado) }
    else render json: { ok: false, error: resultado.mensagem }, status: :unprocessable_content
    end
  end

  def aviso_de_registro(baixa)
    texto = "Baixa de #{EtapasProducao.etapa(@pedido.tipo, baixa.etapa).nome} registrada (#{baixa.linhas.size} #{baixa.linhas.one? ? "linha" : "linhas"})."
    return texto unless baixa.reposicao

    situacao = baixa.reposicao.reload.status == "rascunho" ? "guardadas na reposição em aberto" : "na reposição, que foi para a produção"
    "#{texto} Peças que faltaram #{situacao} ##{baixa.reposicao.uuid.first(8)}."
  end

  # The Conferência's lines to count one by one (Etapa 2.2, 4/4), with what
  # each may redo: Impressão always, Corte when the part cuts.
  def linhas_para_contar(resultado)
    resultado.linhas.map do |l|
      { chave: l.chave, rotulo: "#{RegistrarBaixaService.rotulo(l)} · #{l.item.arte&.titulo}", esperado: l.esperado.to_i,
        contada: resultado.contagem.inicial(l), corta: l.corte_chave.present? }
    end
  end

  def faltas_de_material(resultado)
    resultado.faltas.map do |item|
      { chave: item.chave, material: item.materia_prima.nome_completo, dono: item.client&.name || "Empresa",
        falta: item.falta.to_f, minimo: item.minimo.to_f }
    end
  end

  def set_pedido
    @pedido = visiveis(Pedido).por_uuid!(params[:pedido_uuid])
  end
end
