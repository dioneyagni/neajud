# What a pedido of works without corte shares on its page (DTF since Etapa
# 2.6b1, tecido since 2.7a): found by its type, changed only while editable
# (the cliente final's draft too), and its client the pedido's — the team's
# to choose (D4). The including controller defines `tipo_do_pedido` (one
# type, or several: MateriaisDoPedidoController takes any since 2.3d1).
#
# Usage: class PedidosTecidoController < ApplicationController
#          include AjustesDoPedidoSemCorte
#          def update = atualizar_pedido
module AjustesDoPedidoSemCorte
  extend ActiveSupport::Concern

  included do
    exige :pedidos, :editar
    before_action :set_pedido
    before_action :recusar_fora_do_rascunho
  end

  private

  # The pedido's own fields given, and its client (client_uuid, the team's:
  # a cliente final's pedido is always his own) unless cliente: false — a
  # calçado's client comes from its artes.
  def atualizar_pedido(*campos, cliente: true)
    return redirect_to resumo_pedido_path(@pedido), alert: "The pedido's client is the team's to choose" if cliente && cliente_final? && params.key?(:client_uuid)

    @pedido.assign_attributes(params.permit(*campos))
    @pedido.client = params[:client_uuid].presence && visiveis(Client).ativos.por_uuid!(params[:client_uuid]) if cliente && params.key?(:client_uuid)
    return redirect_to resumo_pedido_path(@pedido), notice: "Pedido updated." if @pedido.save

    redirect_to resumo_pedido_path(@pedido), alert: @pedido.errors.full_messages.to_sentence
  end

  def set_pedido
    @pedido = visiveis(Pedido).where(tipo: tipo_do_pedido).por_uuid!(params[:uuid])
  end

  def recusar_fora_do_rascunho
    return if @pedido.editavel?(cliente_final: cliente_final?)

    redirect_to resumo_pedido_path(@pedido), alert: "#{@pedido.rotulo_lixeira} is #{@pedido.excluido? ? "in the trash" : @pedido.status}; it changes only while editable"
  end
end
