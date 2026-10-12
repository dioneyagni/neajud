# A client's draft between him and the factory (Etapa 2.8, 5/5): he sends it
# and may take it back; the team returns it with a note. Confirming stays
# PedidosController#confirmar, the team's.
class EnviosPedidoController < ApplicationController
  exige :pedidos, :editar
  exige_cliente_final only: %i[enviar retirar]
  exige_equipe only: :devolver
  before_action :set_pedido

  # Usage: POST /pedidos/:uuid/enviar
  def enviar
    responder(EnvioDoPedido.enviar(@pedido, user: Current.user), "Pedido sent to the factory.")
  end

  # Usage: POST /pedidos/:uuid/retirar_envio
  def retirar
    responder(EnvioDoPedido.retirar(@pedido, user: Current.user), "Pedido taken back; send it again when it is ready.")
  end

  # Usage: POST /pedidos/:uuid/devolver, recado=…
  def devolver
    responder(EnvioDoPedido.devolver(@pedido, user: Current.user, recado: params[:recado]), "Pedido returned to the client.")
  end

  private

  # Whoever else has the pedido open sees the new state (AoVivoChannel).
  def responder(evento, aviso)
    return redirect_to resumo_pedido_path(@pedido), alert: evento.errors.full_messages.to_sentence unless evento.persisted?

    CanaisAoVivo.recarregar(@pedido)
    redirect_to resumo_pedido_path(@pedido), notice: aviso
  end

  def set_pedido
    @pedido = visiveis(Pedido).por_uuid!(params[:uuid])
  end
end
