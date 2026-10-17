# The tecido's print price per meter agreed with a client (Etapa 2.7b,
# decided 17/10/2026), on his page — blank follows the dono's (Parâmetros).
# The minimum meters is the dono's only (Q3). The team's, with "ver valores":
# a client never sees another's agreement.
class PrecosTecidoDoClienteController < ApplicationController
  include NumeroDigitado

  exige :clientes, :editar
  exige_acao :ver_valores
  exige_equipe

  # Usage: PATCH /clients/:id/precos_tecido, preco_impressao_metro_tecido=16,50
  def update
    client = visiveis(Client).ativos.por_uuid!(params[:id])
    if client.update(preco_impressao_metro_tecido: decimal_digitado(params[:preco_impressao_metro_tecido]))
      redirect_to client_path(client, anchor: "precos-tecido"), notice: "#{client.name}'s tecido price saved."
    else
      redirect_to client_path(client, anchor: "precos-tecido"), alert: client.errors.full_messages.to_sentence
    end
  end
end
