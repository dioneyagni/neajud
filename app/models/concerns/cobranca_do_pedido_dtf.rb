# How a DTF pedido is charged (Etapa 2.6c, decided 13-14/10/2026): by meter or
# by quantity (D2) and whether the excess is charged, each the pedido's own
# else its client's else the dono's — the cascade dono → cliente → pedido —;
# the starting prices per meter and per unit cut the same way (the client's
# agreed, else the dono's), and the edited ones over them (D3). Confirming
# writes the choices and the starting prices (confirmar_cobranca!), so a
# confirmed pedido never follows a later change.
#
# Usage: pedido.cobranca_efetiva # => "quantidade"
#        pedido.preco_metro_efetivo # => 120.0 (edited, else the starting one)
module CobrancaDoPedidoDtf
  extend ActiveSupport::Concern

  included do
    validates :cobranca_dtf, inclusion: { in: PrecosDoDtf::COBRANCAS, message: "%{value} is not a way to charge; expected one of #{PrecosDoDtf::COBRANCAS.join(", ")}" }, allow_nil: true
    validates :preco_metro, :preco_corte, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  end

  def cobranca_efetiva
    cobranca_dtf || client&.cobranca_dtf || Empresa.atual&.cobranca_dtf || "quantidade"
  end

  def cobra_excedente?
    [ cobrar_excedente, client&.cobrar_excedente_dtf, Empresa.atual&.cobrar_excedente_dtf ].compact.first != false
  end

  def preco_metro_de_partida
    confirmado_com_precos? ? preco_metro_partida : client&.preco_metro_dtf || Empresa.atual&.preco_metro_dtf
  end

  def preco_corte_de_partida
    confirmado_com_precos? ? preco_corte_partida : client&.preco_corte_dtf || Empresa.atual&.preco_corte_dtf
  end

  def preco_metro_efetivo
    preco_metro || preco_metro_de_partida
  end

  def preco_corte_efetivo
    preco_corte || preco_corte_de_partida
  end

  # Writes the choices and the starting prices, the edited ones or the
  # starting ones as charged (confirming).
  def confirmar_cobranca!
    update!(cobranca_dtf: cobranca_efetiva, cobrar_excedente: cobra_excedente?,
            preco_metro_partida: preco_metro_de_partida, preco_metro: preco_metro_efetivo,
            preco_corte_partida: preco_corte_de_partida, preco_corte: preco_corte_efetivo)
  end

  private

  # A draft in the trash still follows the cascade: only confirming writes.
  def confirmado_com_precos?
    dtf? && Pedido::ANTES_DA_CONFIRMACAO.exclude?(status)
  end
end
