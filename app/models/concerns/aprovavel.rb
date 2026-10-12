# The client-approval state of an arte (Etapa 0.5, 4/4; per arte since Etapa
# 1.2, 2/3 — decided 02/10/2026). One request and one approval cover the
# whole arte: each keeps a photo of the version in use of every file
# (VersaoDeArte#versoes_por_arquivo). Only the latest one counts, and only
# while the files it photographed keep those versions — a new version of any
# of them starts over (not sent); a file added later doesn't (it shows as
# "after the approval").
#
#   :nao_enviada  — nobody sent the arte to the client (the default)
#   :aguardando   — sent (SolicitacaoAprovacao), no answer yet
#   :alteracao_pedida — the client asked for changes since it was sent (2.8, 4a)
#   :aprovada_em_outra_versao — the client approved other versions than the
#                   ones in use (2.8, 4a); "Usar esta versão" makes it :aprovada
#   :aprovada     — an AprovacaoArte still valid
#
# Usage: arte.estado_aprovacao                # => :nao_enviada / :aguardando / :aprovada
#        arte.alterada_depois_da_aprovacao?   # => approved once, changed since
#        arte.depois_da_aprovacao?(arquivo)   # => file added after the approval
module Aprovavel
  extend ActiveSupport::Concern

  ROTULOS_ESTADO = { nao_enviada: "not sent for approval", aguardando: "waiting for approval", alteracao_pedida: "waiting for changes",
                     aprovada_em_outra_versao: "approved in another version", aprovada: "already approved" }.freeze

  included do
    has_many :aprovacoes_arte, -> { order(aprovado_em: :desc, id: :desc) }, class_name: "AprovacaoArte", dependent: :restrict_with_error
    has_many :solicitacoes_aprovacao, -> { order(created_at: :desc, id: :desc) }, class_name: "SolicitacaoAprovacao", dependent: :restrict_with_error
    has_many :alteracoes_arte, -> { order(created_at: :desc, id: :desc) }, class_name: "AlteracaoArte", dependent: :restrict_with_error
  end

  # What a request or an approval photographs: the version in use of each
  # active file. Usage: arte.versoes_em_uso_ids # => [171, 172]
  def versoes_em_uso_ids
    arquivos.ativos.where.not(approved_version_id: nil).order(:id).pluck(:approved_version_id)
  end

  def aprovacao_vigente
    ultima_valida(aprovacoes_arte)
  end

  def solicitacao_vigente
    ultima_valida(solicitacoes_aprovacao)
  end

  def estado_aprovacao
    return :aprovada if aprovacao_vigente

    solicitacao = solicitacao_vigente
    return :nao_enviada unless solicitacao
    return :alteracao_pedida if alteracao_pedida(solicitacao)
    return :aprovada_em_outra_versao if aprovacao_em_outra_versao(solicitacao)

    :aguardando
  end

  # The client's answer to the request in force: changes asked, or an
  # approval of other versions — both only count after that request.
  # Usage: arte.alteracao_pedida(arte.solicitacao_vigente)&.recado
  def alteracao_pedida(solicitacao = solicitacao_vigente)
    depois_de(solicitacao, alteracoes_arte)
  end

  def aprovacao_em_outra_versao(solicitacao = solicitacao_vigente)
    depois_de(solicitacao, aprovacoes_arte)
  end

  # Usage: "#{arte.titulo} is #{arte.rotulo_estado_aprovacao}"
  def rotulo_estado_aprovacao
    ROTULOS_ESTADO.fetch(estado_aprovacao)
  end

  # Not while the client's approval of other versions waits for the team:
  # that one wasn't undone by a change, it never matched.
  def alterada_depois_da_aprovacao?
    aprovacao_vigente.nil? && ultima(aprovacoes_arte).present? && aprovacao_em_outra_versao.nil?
  end

  # A file the approval didn't see: added (or brought in) after it.
  def depois_da_aprovacao?(arquivo)
    aprovacao = aprovacao_vigente
    aprovacao.present? && !aprovacao.versoes_por_arquivo.key?(arquivo.id)
  end

  # The file whose new version undid the latest approval.
  def alterado_depois_da_aprovacao?(arquivo)
    aprovacao = ultima(aprovacoes_arte)
    versao = aprovacao&.versoes_por_arquivo&.[](arquivo.id)
    alterada_depois_da_aprovacao? && versao.present? && versao != arquivo.approved_version_id
  end

  private

  # A query, not the loaded list: a new Arte starts with its lists loaded
  # (empty) in memory, so a request made right after was invisible to it.
  def ultima(registros)
    registros.validas.first
  end

  def depois_de(solicitacao, registros)
    registro = ultima(registros)
    registro if solicitacao && registro && registro.created_at >= solicitacao.created_at
  end

  def ultima_valida(registros)
    registro = ultima(registros)
    registro if registro&.valido_para?(arquivos.ativos.pluck(:id, :approved_version_id).to_h)
  end
end
