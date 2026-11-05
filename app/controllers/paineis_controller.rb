# The Painel (Painel 1/4, decided 04/11/2026): every pedido as a row, every
# stage as a column, from the files to the delivery — the same permission
# and visibility as the Pedidos (Q12b). One pedido's row comes back alone
# for the live update, and its items when the row is opened.
class PaineisController < ApplicationController
  exige :pedidos, :ver

  # Usage: GET /painel (?entregues=1 adds the ones delivered in the last 7 days)
  def show
    @entregues = params[:entregues] == "1"
    @painel = PainelDeProducao.call(visiveis(Pedido), entregues: @entregues, cliente_final: cliente_final?)
  end

  # One row, in the columns the page shows (?colunas[]=…); 204 when the
  # pedido left the Painel (trashed, delivered long ago) or is not visible.
  # Usage: GET /painel/pedidos/:uuid?colunas[]=arquivos&colunas[]=corte
  def linha
    linha = PainelDeProducao.linha(visiveis(Pedido), params[:uuid], cliente_final: cliente_final?)
    return head :no_content unless linha

    render partial: "paineis/pedido", locals: { linha: linha, colunas: colunas_pedidas }
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
