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
    helper_method :visiveis, :cliente_final?, :aberto_ao_cliente?, :pode_baixar_original?, :pode_ver_precos?
    after_action :verificar_visibilidade, unless: -> { Rails.env.production? }
  end

  class_methods do
    # Usage: nao_le_registros only: %i[new create]
    def nao_le_registros(**options)
      before_action(**options) { @visibilidade_aplicada = true }
    end

    # A page of a kind the client's grid closes answers 404, like a record
    # he doesn't see (Etapa 2.8, 3a). Usage: exige_aberto :cortes, only: :corte
    def exige_aberto(tipo, **options)
      before_action(**options) { raise ActiveRecord::RecordNotFound, "#{tipo} is closed to this client" unless aberto_ao_cliente?(tipo) }
    end

    # Downloading an original: the team's baixar_producao, or a cliente
    # final with "original" open (3a). Usage: exige_baixar_original only: :download
    def exige_baixar_original(**options)
      before_action(**options) { exigir!(pode_baixar_original?, "baixar_producao") }
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

  # Always true for the team. Usage: aberto_ao_cliente?(:cortes)
  def aberto_ao_cliente?(tipo)
    visibilidade.aberto?(tipo)
  end

  # A cliente final by his grid's "original"; the team by its função.
  def pode_baixar_original?
    cliente_final? ? aberto_ao_cliente?(:original) : pode_acao?(:baixar_producao)
  end

  # The price per pair: a cliente final by "valores" (never the cost —
  # that stays pode_acao?(:ver_valores), which a client never has).
  def pode_ver_precos?
    cliente_final? ? aberto_ao_cliente?(:valores) : pode_acao?(:ver_valores)
  end

  # A refusal (4xx) before anything was read shows no records.
  def verificar_visibilidade
    return if @visibilidade_aplicada || response.status >= 400

    raise VisibilidadeNaoAplicada, "#{self.class.name}##{action_name} finished without visiveis(…): read its records through visiveis(Model), or declare `nao_le_registros only: :#{action_name}`"
  end
end
