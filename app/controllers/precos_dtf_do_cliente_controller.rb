# The DTF prices agreed with a client (Etapa 2.6c, decided 13-14/10/2026), on
# his page: the price per meter and per unit cut, how his pedidos are charged
# and whether the excess is — blank follows the dono's (Parâmetros). The
# team's, with "ver valores": a client never sees another's agreement.
class PrecosDtfDoClienteController < ApplicationController
  include NumeroDigitado

  exige :clientes, :editar
  exige_acao :ver_valores
  exige_equipe

  # Usage: PATCH /clients/:id/precos_dtf, preco_metro_dtf=110, preco_corte_dtf=0,05, cobranca_dtf=metro, cobrar_excedente_dtf=0
  def update
    client = visiveis(Client).ativos.por_uuid!(params[:id])
    if client.update(precos)
      redirect_to client_path(client, anchor: "precos-dtf"), notice: "#{client.name}'s DTF prices saved."
    else
      redirect_to client_path(client, anchor: "precos-dtf"), alert: client.errors.full_messages.to_sentence
    end
  end

  private

  def precos
    {
      preco_metro_dtf: decimal_digitado(params[:preco_metro_dtf]), preco_corte_dtf: decimal_digitado(params[:preco_corte_dtf]),
      cobranca_dtf: params[:cobranca_dtf].presence, cobrar_excedente_dtf: params[:cobrar_excedente_dtf].presence
    }
  end
end
