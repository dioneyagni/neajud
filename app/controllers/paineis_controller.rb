# The Painel (Painel 1/4, decided 04/11/2026): every pedido as a row, every
# stage as a column, from the files to the delivery — the same permission
# and visibility as the Pedidos (Q12b). A pedido's items come back when its
# row is opened. Painel 2/4b: the blocks in time, the previsão and each
# sector's queue (FilaDeProducao); the page refreshes itself when the queue
# changes (CanaisAoVivo.avisar_fila). Painel 2/4c: the Linha do tempo, the
# second view, its window and order in the address (Q3a, Q6a).
class PaineisController < ApplicationController
  exige :pedidos, :ver

  # Usage: GET /painel (?entregues=1 adds the ones delivered in the last 7 days)
  #        GET /painel?visao=tempo&de=2026-11-05&ordem=prazo
  def show
    @entregues = params[:entregues] == "1"
    @visao = params[:visao] == "tempo" ? "tempo" : "etapas"
    @de = inicio_da_janela
    @ordem = LinhaDoTempo::ORDENS.include?(params[:ordem]) ? params[:ordem] : "chegada"
    @painel = PainelDeProducao.call(visiveis(Pedido), entregues: @entregues, cliente_final: cliente_final?, janela: @de..(@de + LinhaDoTempo::DIAS - 1))
    # Painel 3/4a: each row's "Histórico da programação", read at once (the team's only).
    @historicos = visiveis(MovimentoDaFila).por_pedido(@painel.linhas.flat_map(&:com_reposicoes).map { |linha| linha.pedido.id })
    # Painel 2/4a: the turno on now, in the header (none for a cliente final).
    @calendario = CalendarioDeProducao.new(turnos: visiveis(Turno).ativos.to_a, excecoes: visiveis(ExcecaoCalendario).to_a)
  end

  # Usage: GET /painel/pedidos/:uuid/itens?colunas[]=…
  def itens
    pedido = visiveis(Pedido).por_uuid!(params[:uuid])
    render partial: "paineis/itens", locals: { itens: ItensDoPainel.call(pedido), colunas: colunas_pedidas }
  end

  private

  # A date that isn't one goes back to the default window.
  def inicio_da_janela
    Date.iso8601(params[:de].to_s)
  rescue Date::Error
    LinhaDoTempo.inicio_padrao
  end

  def colunas_pedidas
    LinhaDoPainel::COLUNAS.slice(*Array(params[:colunas]))
  end
end
