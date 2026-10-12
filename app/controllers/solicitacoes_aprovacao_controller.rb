# "Enviar para aprovação" (Etapa 0.5, 4/4): marks that the arte — the version
# in use of each of its files (Etapa 1.2, 2/3) — was sent to the client; only then it waits for approval and the
# "register approval" button shows. Cancel keeps it in the history.
class SolicitacoesAprovacaoController < ApplicationController
  exige_acao :aprovar_arte
  # Sending for approval is the team's; the client answers it (Etapa 2.8, 4a).
  exige_equipe
  exige :artes, :ver

  # Usage: POST /arquivos/:arquivo_id/solicitacoes_aprovacao (arquivo_solicitacoes_path)
  def create
    arte = visiveis(Arquivo).ativos.find_by!(uuid: params[:arquivo_id])
    # After the client asked for changes, the team sends it again (Etapa 2.8, 4a).
    return redirect_to arquivo_path(arte), alert: "#{arte.filename} is #{arte.rotulo_estado_aprovacao} already." unless %i[nao_enviada alteracao_pedida].include?(arte.estado_aprovacao)

    solicitacao = visiveis(SolicitacaoAprovacao).new(arquivo: arte, arquivo_version: arte.approved_version, user: Current.user)
    return redirect_to arquivo_path(arte), alert: solicitacao.errors.full_messages.to_sentence unless solicitacao.save

    redirect_to arquivo_path(arte), notice: "#{arte.arte.titulo} sent for approval (#{solicitacao.arquivo_version_ids.size} #{"file".pluralize(solicitacao.arquivo_version_ids.size)})."
  end

  def cancelar
    solicitacao = visiveis(SolicitacaoAprovacao).find_by!(uuid: params[:uuid])
    solicitacao.cancelar!(por: Current.user)
    redirect_to arquivo_path(solicitacao.arquivo), notice: "Request cancelled; it stays in the history."
  end
end
