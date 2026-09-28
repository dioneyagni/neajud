# A record cancelled by mistake stays in the history (docs/plano.md: nothing
# is physically deleted), marked with when and by whom. Shared by
# SolicitacaoAprovacao and AprovacaoArte.
# Usage: registro.cancelar!(por: Current.user); Model.validas
module Cancelavel
  extend ActiveSupport::Concern

  included do
    belongs_to :cancelada_por, class_name: "User", optional: true
    scope :validas, -> { where(cancelada_em: nil) }
  end

  def cancelada?
    cancelada_em.present?
  end

  def cancelar!(por:)
    update_columns(cancelada_em: Time.current, cancelada_por_id: por&.id)
  end
end
