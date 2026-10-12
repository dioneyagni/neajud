# One client's exceptions to the empresa's default visibility (Etapa 2.8, 3a;
# decided 10/10/2026), on the client's page — by who manages the client's
# accesses ("gerenciar usuários"). A kind on "padrao" follows the grid.
class VisibilidadeDoClienteController < ApplicationController
  exige_acao :gerenciar_usuarios

  # Usage: PATCH /clients/:id/visibilidade (tipos[cortes]=1&tipos[pedidos]=padrao…)
  def update
    client = visiveis(Client).por_uuid!(params[:id])
    if client.update(visibilidade: TiposParaCliente.ler(tipos))
      redirect_to client_path(client, anchor: "visibilidade"), notice: "#{client.name}'s visibility saved."
    else
      redirect_to client_path(client, anchor: "visibilidade"), alert: client.errors.full_messages.to_sentence
    end
  end

  private

  def tipos
    params.fetch(:tipos, {}).permit(*TiposParaCliente::TIPOS).to_h
  end
end
