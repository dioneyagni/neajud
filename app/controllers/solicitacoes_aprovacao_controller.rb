# "Enviar para aprovação" (Etapa 0.5, 4/4): marks that the version in use of
# an arte was sent to the client; only then it waits for approval and the
# "register approval" button shows. Cancel keeps it in the history.
class SolicitacoesAprovacaoController < ApplicationController
  exige_acao :aprovar_arte
  exige :artes, :ver

  # Usage: POST /arquivos/:arquivo_id/solicitacoes_aprovacao (arquivo_solicitacoes_path)
  def create
    arte = Arquivo.ativos.find_by!(uuid: params[:arquivo_id])
    return redirect_to arquivo_path(arte), alert: "#{arte.filename} is #{arte.rotulo_estado_aprovacao} already." unless arte.estado_aprovacao == :nao_enviada

    solicitacao = SolicitacaoAprovacao.new(arquivo: arte, arquivo_version: arte.approved_version, user: Current.user)
    return redirect_to arquivo_path(arte), alert: solicitacao.errors.full_messages.to_sentence unless solicitacao.save

    redirect_to arquivo_path(arte), notice: "v#{solicitacao.arquivo_version.version_number} of #{arte.filename} sent for approval."
  end

  def cancelar
    solicitacao = SolicitacaoAprovacao.find_by!(uuid: params[:uuid])
    solicitacao.cancelar!(por: Current.user)
    redirect_to arquivo_path(solicitacao.arquivo), notice: "Request cancelled; it stays in the history."
  end
end
