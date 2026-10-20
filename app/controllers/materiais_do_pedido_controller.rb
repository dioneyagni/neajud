# Where a draft's materials come from (Etapa 2.3d1, decided 19/10/2026), any
# type: whose fabric — blank inherits the molde's or the client's
# (DonoDoTecido); the cliente final's too on his draft, he knows whether he
# brings it — and the paper or DTF film it prints on, the team's.
class MateriaisDoPedidoController < ApplicationController
  include AjustesDoPedidoSemCorte

  # Usage: PATCH /pedidos/:uuid/materiais, dono_tecido=empresa|cliente|"" (inherit),
  #        material_impressao_uuid=…|"" (the default; the team's)
  def update
    if params.key?(:material_impressao_uuid)
      return redirect_to resumo_pedido_path(@pedido), alert: "The paper or film is the team's to choose" if cliente_final?

      @pedido.material_impressao = params[:material_impressao_uuid].presence && visiveis(MateriaPrima).por_uuid!(params[:material_impressao_uuid])
    end
    atualizar_pedido(:dono_tecido, cliente: false)
  end

  private

  def tipo_do_pedido = Pedido::TIPOS
end
