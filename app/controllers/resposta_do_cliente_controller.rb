# The cliente final answers a request for approval in the system (Etapa 2.8,
# 4a): "Aprovar" with the version of each file he chose, or "Pedir
# alteração" with a note. The team registers approvals by channel instead
# (AprovacoesController); these are the client's own.
class RespostaDoClienteController < ApplicationController
  exige :artes, :ver
  exige_acao :aprovar_arte
  exige_cliente_final
  before_action :set_arquivo

  # Usage: POST /arquivos/:arquivo_id/aprovar_no_sistema, versoes[<arquivo uuid>]=<version uuid>
  def aprovar
    aprovacao = AprovarNoSistemaService.call(@arquivo, user: Current.user, versoes: versoes_escolhidas)
    return redirect_to arquivo_path(@arquivo), alert: aprovacao.errors.full_messages.to_sentence unless aprovacao.persisted?

    aviso = @arquivo.estado_aprovacao == :aprovada ? "approved" : "approved in other versions than the ones in use; the factory will switch to them"
    redirect_to arquivo_path(@arquivo), notice: "#{@arquivo.arte.titulo} #{aviso}."
  end

  # Usage: POST /arquivos/:arquivo_id/pedir_alteracao, recado=…
  def pedir_alteracao
    alteracao = PedirAlteracaoService.call(@arquivo, user: Current.user, recado: params[:recado])
    return redirect_to arquivo_path(@arquivo), alert: alteracao.errors.full_messages.to_sentence unless alteracao.persisted?

    redirect_to arquivo_path(@arquivo), notice: "Changes asked for #{@arquivo.arte.titulo}; the factory will send it again."
  end

  private

  # { arquivo uuid => version uuid }: the service checks each belongs to its file.
  def versoes_escolhidas
    versoes = params.fetch(:versoes, {})
    versoes.permit(*versoes.keys).to_h
  end

  def set_arquivo
    @arquivo = visiveis(Arquivo).ativos.where(category: "artes").por_uuid!(params[:arquivo_id])
  end
end
