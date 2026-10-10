# Etapa 2.8 (1/5): every action reads records through the visibility policy
# (Visibilidade) — `visiveis(Pedido)`, `visiveis(Arquivo).por_uuid!(…)` — so a
# cliente final only ever gets its client's rows (another's uuid is a 404).
#
# The guard: outside production, an action that finished without calling
# `visiveis` raises, naming itself. Actions that read no client records
# (sign-in, the dono's parameters) declare it: `nao_le_registros only: :edit`.
# A new screen can't forget the policy and still pass the specs.
module ControleDeVisibilidade
  extend ActiveSupport::Concern

  class VisibilidadeNaoAplicada < StandardError; end

  included do
    helper_method :visiveis, :cliente_final?
    after_action :verificar_visibilidade, unless: -> { Rails.env.production? }
  end

  class_methods do
    # Usage: nao_le_registros only: %i[new create]
    def nao_le_registros(**options)
      before_action(**options) { @visibilidade_aplicada = true }
    end
  end

  private

  # Usage: visiveis(Molde).ativos.order(:nome)
  def visiveis(modelo)
    @visibilidade_aplicada = true
    visibilidade.escopo(modelo)
  end

  def visibilidade
    @visibilidade ||= Visibilidade.new(Current.user&.cliente)
  end

  def cliente_final?
    visibilidade.cliente?
  end

  # A refusal (4xx) before anything was read shows no records.
  def verificar_visibilidade
    return if @visibilidade_aplicada || response.status >= 400

    raise VisibilidadeNaoAplicada, "#{self.class.name}##{action_name} finished without visiveis(…): read its records through visiveis(Model), or declare `nao_le_registros only: :#{action_name}`"
  end
end
