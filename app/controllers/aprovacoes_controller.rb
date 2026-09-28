# Registering a client's approval of an arte (Etapa 0.5, 4/4) — from the
# arte page or from a pedido (it returns there via voltar_para) — cancelling
# one registered by mistake, and downloading its attachment.
class AprovacoesController < ApplicationController
  exige_acao :aprovar_arte, only: %i[new create cancelar]
  exige :artes, :ver
  before_action :set_arte, only: %i[new create]
  before_action :set_aprovacao, only: %i[cancelar anexo]

  def new
    unless @arte.estado_aprovacao == :aguardando
      return redirect_to arquivo_path(@arte), alert: "#{@arte.filename} is #{@arte.rotulo_estado_aprovacao}; send it for approval first."
    end

    @aprovacao = AprovacaoArte.new(arquivo: @arte, aprovado_em: Date.current, canal: "whatsapp")
  end

  def create
    @aprovacao = RegistrarAprovacaoService.call(@arte, user: Current.user, dados: aprovacao_params, anexo: params.dig(:aprovacao, :anexo))
    return render :new, status: :unprocessable_content unless @aprovacao.persisted?

    redirect_to voltar_para, notice: "Approval of #{@arte.filename} (v#{@aprovacao.arquivo_version.version_number}) registered."
  end

  def cancelar
    @aprovacao.cancelar!(por: Current.user)
    redirect_to arquivo_path(@aprovacao.arquivo), notice: "Approval cancelled; it stays in the history."
  end

  # Always a download, never rendered inline: it is a file someone uploaded.
  def anexo
    return head :not_found unless @aprovacao.anexo_path && File.exist?(@aprovacao.anexo_path)

    send_file @aprovacao.anexo_path, type: @aprovacao.anexo_tipo, disposition: "attachment", filename: @aprovacao.anexo_nome
  end

  private

  def set_arte
    @arte = Arquivo.ativos.find_by!(uuid: params[:arquivo_id])
  end

  def set_aprovacao
    @aprovacao = AprovacaoArte.find_by!(uuid: params[:uuid])
  end

  # Only paths of this app (url_from refuses other hosts), else the arte page.
  def voltar_para
    url_from(params[:voltar_para]) || arquivo_path(@arte)
  end
  helper_method :voltar_para

  def aprovacao_params
    params.expect(aprovacao: %i[canal canal_detalhe aprovado_em observacao]).to_h
  end
end
