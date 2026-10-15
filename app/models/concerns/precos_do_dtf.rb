# The DTF's prices of the dono (Empresa) and the ones agreed with a client
# (Client) — Etapa 2.6c, decided 13-14/10/2026: the price per meter, per unit
# cut, how a pedido is charged and whether the excess is. A client's blank
# follows the dono's (the cascade dono → cliente → pedido, Pedido#cobranca_efetiva).
# A new price per meter recalculates the etiquetas' unit prices it gives
# (PrecoDaEtiqueta); each model says which (etiquetas_do_preco).
#
# Usage: client.update!(preco_metro_dtf: 110, cobranca_dtf: "metro")
module PrecosDoDtf
  extend ActiveSupport::Concern

  COBRANCAS = %w[quantidade metro].freeze

  included do
    validates :preco_metro_dtf, :preco_corte_dtf, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
    validates :cobranca_dtf, inclusion: { in: COBRANCAS, message: "%{value} is not a way to charge; expected one of #{COBRANCAS.join(", ")}" }, allow_nil: true
    after_update_commit -> { EncaixeDaEtiqueta.atualizar_varios!(etiquetas_do_preco) }, if: :saved_change_to_preco_metro_dtf?
  end
end
