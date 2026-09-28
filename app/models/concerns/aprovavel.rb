# The client-approval state of an arte (Etapa 0.5, 4/4), always about the
# version in use (approved_version): a new version waits for its own
# approval, even if an earlier one was approved.
#
# Usage: arte.estado_aprovacao       # => :aprovada or :aguardando
#        arte.aprovacao_vigente      # => the AprovacaoArte of the version in use
#        arte.aprovada_versao_anterior? # => true when only an older version was approved
module Aprovavel
  extend ActiveSupport::Concern

  included do
    has_many :aprovacoes_arte, -> { order(aprovado_em: :desc, id: :desc) }, class_name: "AprovacaoArte", dependent: :destroy
  end

  def aprovacao_vigente
    return if approved_version_id.nil?

    aprovacoes_arte.find { |aprovacao| !aprovacao.cancelada? && aprovacao.arquivo_version_id == approved_version_id }
  end

  def estado_aprovacao
    aprovacao_vigente ? :aprovada : :aguardando
  end

  def aprovada_versao_anterior?
    aprovacao_vigente.nil? && aprovacoes_arte.any? { |aprovacao| !aprovacao.cancelada? }
  end
end
