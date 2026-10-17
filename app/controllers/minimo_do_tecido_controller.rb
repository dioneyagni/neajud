# Approving a tecido item below the dono's minimum meters (Etapa 2.7b,
# decided 17/10/2026, Q2): the team's, with the action "aprovar abaixo do
# mínimo". It holds while the item keeps the meters approved; who approved
# and when stay recorded. Charged on the real meters.
class MinimoDoTecidoController < ApplicationController
  exige :pedidos, :editar
  exige_acao :aprovar_abaixo_do_minimo
  exige_equipe

  # Usage: POST /pedidos/:uuid/tecido/aprovar_minimo, item_uuid=…
  def aprovar
    pedido = visiveis(Pedido).where(tipo: "tecido").por_uuid!(params[:uuid])
    item = pedido.itens_pedido.por_uuid!(params[:item_uuid])
    return redirect_to resumo_pedido_path(pedido), alert: "#{pedido.rotulo_lixeira} is #{pedido.status}; it changes only while editable" unless pedido.editavel?
    return redirect_to resumo_pedido_path(pedido), alert: "#{item.arte.titulo} is not below the minimum (#{item.metros.to_d.to_s("F")} m)" unless item.abaixo_do_minimo?

    item.aprovar_minimo!(Current.user)
    redirect_to resumo_pedido_path(pedido), notice: "#{item.arte.titulo}: approved below the minimum."
  end
end
