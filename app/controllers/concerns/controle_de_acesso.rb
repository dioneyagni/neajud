# Server-side permissions (Etapa 0.5, 2/4). Each controller declares what its
# actions need; Autorizacao decides. The UI hides what a user can't do, but
# this is what actually refuses it (403 + "Sem permissão").
#
# Usage:
#   exige :pedidos, :ver, only: %i[index show]
#   exige_acao :baixar_producao, only: :download
#   exige_dono only: :index
#   exige_cliente_final / exige_equipe only: :create
module ControleDeAcesso
  extend ActiveSupport::Concern

  included do
    helper_method :pode?, :pode_acao?, :dono?
  end

  class_methods do
    def exige(area, nivel, **options)
      before_action(**options) { exigir!(pode?(area, nivel), "#{area}: #{nivel}") }
    end

    def exige_acao(acao, **options)
      before_action(**options) { exigir!(pode_acao?(acao), acao.to_s) }
    end

    def exige_dono(**options)
      before_action(**options) { exigir!(dono?, "dono") }
    end

    # Etapa 2.8 (4a): actions only a cliente final takes (his own approval),
    # and actions only the team takes, whatever the grid gives a client.
    def exige_cliente_final(**options)
      before_action(**options) { exigir!(Current.user&.cliente.present?, "a cliente final") }
    end

    def exige_equipe(**options)
      before_action(**options) { exigir!(Current.user.present? && Current.user.cliente.nil?, "the team") }
    end
  end

  private

  def autorizacao
    Current.user&.autorizacao || Autorizacao.new(nil)
  end

  def pode?(area, nivel)
    autorizacao.pode?(area, nivel)
  end

  def pode_acao?(acao)
    autorizacao.pode_acao?(acao)
  end

  def dono?
    autorizacao.dono?
  end

  def exigir!(permitido, requisito)
    recusar_acesso(requisito) unless permitido
  end

  def recusar_acesso(requisito)
    @requisito = requisito
    respond_to do |format|
      format.html { render "shared/sem_permissao", status: :forbidden }
      format.json { render json: { ok: false, error: "No permission: needs #{requisito}" }, status: :forbidden }
      format.any { head :forbidden }
    end
  end
end
