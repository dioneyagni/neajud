# The client-approval state of an arte (Etapa 0.5, 4/4), always about the
# version in use (approved_version). Changed before merge (28/09/2026): an
# arte only waits once someone sends it for approval — until then there is
# no state to show. A new version starts over (not sent).
#
#   :nao_enviada  — nobody sent this version to the client (the default)
#   :aguardando   — sent (SolicitacaoAprovacao), no approval yet
#   :aprovada     — an AprovacaoArte for this version
#
# Usage: arte.estado_aprovacao         # => :nao_enviada / :aguardando / :aprovada
#        arte.solicitacao_vigente       # => the request of the version in use
#        arte.aprovada_versao_anterior? # => an older version was approved
module Aprovavel
  extend ActiveSupport::Concern

  ROTULOS_ESTADO = { nao_enviada: "not sent for approval", aguardando: "waiting for approval", aprovada: "already approved" }.freeze

  included do
    has_many :aprovacoes_arte, -> { order(aprovado_em: :desc, id: :desc) }, class_name: "AprovacaoArte", dependent: :destroy
    has_many :solicitacoes_aprovacao, -> { order(created_at: :desc, id: :desc) }, class_name: "SolicitacaoAprovacao", dependent: :destroy
  end

  def aprovacao_vigente
    da_versao_em_uso(aprovacoes_arte)
  end

  def solicitacao_vigente
    da_versao_em_uso(solicitacoes_aprovacao)
  end

  def estado_aprovacao
    return :aprovada if aprovacao_vigente
    return :aguardando if solicitacao_vigente

    :nao_enviada
  end

  # Usage: "#{arte.filename} is #{arte.rotulo_estado_aprovacao}"
  def rotulo_estado_aprovacao
    ROTULOS_ESTADO.fetch(estado_aprovacao)
  end

  def aprovada_versao_anterior?
    aprovacao_vigente.nil? && aprovacoes_arte.any? { |aprovacao| !aprovacao.cancelada? }
  end

  private

  # Loaded association + find, so a pedido page with many pieces can preload.
  def da_versao_em_uso(registros)
    return if approved_version_id.nil?

    registros.find { |registro| !registro.cancelada? && registro.arquivo_version_id == approved_version_id }
  end
end
