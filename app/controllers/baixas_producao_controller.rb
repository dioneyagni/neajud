# The baixa of a production stage, from the Impressão, Corte, Estamparia and
# Conferência pages (Etapa 2.2, 2/3). JSON for the baixa Stimulus controller:
# ok (the page reloads and shows the flash), aviso (outside the dono's band:
# correct or confirm), falta_material (the entry to launch with it, decided
# 05/11/2026) or error. Undoing one (3/3) goes back to the page.
#
# Usage: POST /pedidos/:pedido_uuid/baixas (etapa, nivel, alvo, medida, confirmar; medidas[<material uuid>] — Etapa 2.3e;
#        entradas[<material uuid>:<client uuid|empresa>], autorizador[email], autorizador[senha] — the material missing)
#        DELETE /pedidos/:pedido_uuid/baixas/:uuid
#        GET /pedidos/:pedido_uuid/baixas/maquina?etapa=calandra — the machine the editor opens on (Máquinas 4/5a)
class BaixasProducaoController < ApplicationController
  include EntradaDaFaltaAutorizada
  exige_acao :atualizar_producao
  before_action :set_pedido
  limita_senha_do_autorizador only: :create

  def create
    resultado = RegistrarBaixaService.call(@pedido, etapa: params[:etapa], nivel: params[:nivel], alvo: params[:alvo],
                                                    medida: params[:medida], confirmar: params[:confirmar] == "1",
                                                    contagens: params[:contagens]&.to_unsafe_h, refazer: params[:refazer]&.to_unsafe_h,
                                                    medidas: params[:medidas]&.to_unsafe_h, maquina: params[:maquina],
                                                    movimentos: visiveis(MovimentoDaFila), maquinas: visiveis(Maquina), **campos_da_entrada, **autoria)
    responder(resultado)
  rescue EtapasProducao::Invalida => e
    render json: { ok: false, error: e.message }, status: :unprocessable_content
  end

  # Q4a: the last baixa's machine, the one it is held on or where the
  # queue put it — read when the editor opens, so the pedido's page doesn't
  # build the whole queue. The queue reads the whole factory (FilaDeProducao).
  def maquina
    etapa = EtapasProducao.etapa(@pedido.tipo, params[:etapa], pedido: @pedido)
    movimentos = visiveis(MovimentoDaFila)
    sugestao = MaquinaDaBaixa.sugerida(@pedido, etapa, fixacoes: movimentos.fixacoes, maquinas: visiveis(Maquina)) { FilaDeProducao.call(ordens: movimentos.ordens, fixacoes: movimentos.fixacoes) }
    render json: { maquina: sugestao&.maquina&.uuid, nome: sugestao&.maquina&.nome, origem: sugestao&.origem }
  rescue EtapasProducao::Invalida => e
    render json: { error: e.message }, status: :unprocessable_content
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
      flash[:notice] = [ aviso_de_registro(resultado.baixa), aviso_da_troca(resultado.troca) ].compact.join(" ")
      render json: { ok: true }
    when :aviso then render json: { ok: false, aviso: resultado.mensagem }
    when :falta_material then render json: { ok: false, falta_material: resultado.mensagem, **dialogo_da_falta(resultado.faltas) }
    when :contar then render json: { ok: false, contar: resultado.mensagem, linhas: linhas_para_contar(resultado) }
    else render json: { ok: false, error: resultado.mensagem }, status: :unprocessable_content
    end
  end

  def aviso_de_registro(baixa)
    texto = "Baixa de #{EtapasProducao.etapa(@pedido.tipo, baixa.etapa).nome} registrada (#{baixa.linhas.size} #{baixa.linhas.one? ? "linha" : "linhas"})#{" na #{baixa.maquina.nome}" if baixa.maquina}."
    return texto unless baixa.reposicao

    situacao = baixa.reposicao.reload.status == "rascunho" ? "guardadas na reposição em aberto" : "na reposição, que foi para a produção"
    "#{texto} Peças que faltaram #{situacao} ##{baixa.reposicao.uuid.first(8)}."
  end

  # Q1a: the hold followed the baixa.
  def aviso_da_troca(troca)
    return unless troca

    "Ela estava presa na #{troca.de_maquina.nome}: o resto fica na #{troca.para_maquina.nome} até terminar."
  end

  # The Conferência's lines to count one by one (Etapa 2.2, 4/4), with what
  # each may redo: Impressão always, Corte when the part cuts.
  def linhas_para_contar(resultado)
    resultado.linhas.map do |l|
      { chave: l.chave, rotulo: "#{RegistrarBaixaService.rotulo(l)} · #{l.item.arte&.titulo}", esperado: l.esperado.to_i,
        contada: resultado.contagem.inicial(l), corta: l.corte_chave.present? }
    end
  end

  def set_pedido
    @pedido = visiveis(Pedido).por_uuid!(params[:pedido_uuid])
  end
end
