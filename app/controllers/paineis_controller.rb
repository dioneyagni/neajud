# The Painel (Painel 1/4, decided 04/11/2026): every pedido as a row, every
# stage as a column, from the files to the delivery — the same permission
# and visibility as the Pedidos (Q12b). A pedido's items come back when its
# row is opened. Painel 2/4b: the blocks in time, the previsão and each
# sector's queue (FilaDeProducao); the page refreshes itself when the queue
# changes (CanaisAoVivo.avisar_fila).
class PaineisController < ApplicationController
  exige :pedidos, :ver

  # Usage: GET /painel (?entregues=1 adds the ones delivered in the last 7 days)
  def show
    @entregues = params[:entregues] == "1"
    @painel = PainelDeProducao.call(visiveis(Pedido), entregues: @entregues, cliente_final: cliente_final?)
    # Painel 2/4a: the turno on now, in the header (none for a cliente final).
    @calendario = CalendarioDeProducao.new(turnos: visiveis(Turno).ativos.to_a, excecoes: visiveis(ExcecaoCalendario).to_a)
  end

  # Usage: GET /painel/pedidos/:uuid/itens?colunas[]=…
  def itens
    pedido = visiveis(Pedido).por_uuid!(params[:uuid])
    render partial: "paineis/itens", locals: { itens: ItensDoPainel.call(pedido), colunas: colunas_pedidas }
  end

  private

  def colunas_pedidas
    LinhaDoPainel::COLUNAS.slice(*Array(params[:colunas]))
  end
end
