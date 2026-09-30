# Logical deletion (Etapa 0.4, docs/plano.md): the row stays, deleted_at marks
# it. No default_scope on purpose — records already in use (a pedido's arte, a
# molde's client) must keep showing, with an "excluído em" badge; listings
# and pickers opt in with `ativos`. Associating a deleted record to a new one
# is refused by ReferenciaAtiva.
#
# Usage:
#   client.excluir!(changed_by: request.remote_ip, user: Current.user)
#   Client.ativos.order(:name)
#   client.restaurar!(changed_by: request.remote_ip, user: Current.user)
module Excluivel
  extend ActiveSupport::Concern

  included do
    has_many :exclusao_logs, as: :registro, dependent: :destroy

    scope :ativos, -> { where(deleted_at: nil) }
    scope :excluidos, -> { where.not(deleted_at: nil) }
  end

  class_methods do
    # For index pages that count children with a LEFT JOIN + GROUP BY: counts
    # only the ones not in the trash. Arel, not an SQL string, so no
    # interpolation reaches .select (Brakeman stays at 0 warnings).
    # Usage: Client.left_joins(:moldes).select(Client.arel_table[Arel.star], Molde.contagem_ativos(as: "moldes_count"))
    def contagem_ativos(as:)
      id_se_ativo = Arel::Nodes::Case.new.when(arel_table[:deleted_at].eq(nil)).then(arel_table[:id])
      Arel::Nodes::Count.new([ id_se_ativo ], true).as(as)
    end
  end

  def excluido?
    deleted_at.present?
  end

  # update_columns: a legacy row that no longer passes today's validations
  # must still be deletable.
  # user is nil only outside a request (console, specs); changed_by is the IP.
  def excluir!(changed_by:, user: nil)
    registrar_exclusao!("excluido", changed_by, user) do
      update_columns(deleted_at: Time.current, deleted_by_id: user&.id, restored_at: nil, restored_by_id: nil)
    end
  end

  def restaurar!(changed_by:, user: nil)
    registrar_exclusao!("restaurado", changed_by, user) do
      update_columns(deleted_at: nil, restored_at: Time.current, restored_by_id: user&.id)
    end
  end

  # How the record is named in the trash and in error messages. Models whose
  # name column isn't `nome` override it.
  def rotulo_lixeira
    nome
  end

  # Usage: "Client \"Fagner\" is in the trash (deleted 26/09/2026) …"
  def aviso_na_lixeira
    "#{model_name.human} \"#{rotulo_lixeira}\" is in the trash (deleted #{deleted_at.strftime('%d/%m/%Y')}). Restore it from Lixeira instead of registering it again."
  end

  private

  def registrar_exclusao!(acao, changed_by, user)
    transaction do
      yield
      exclusao_logs.create!(acao: acao, registro_rotulo: rotulo_lixeira.to_s, changed_by: changed_by, user: user)
    end
  end
end
