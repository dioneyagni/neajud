# The Painel (Painel 1/4, decided 04/11/2026): every pedido as a row, every
# stage as a column, from the files to the delivery — the same permission
# and visibility as the Pedidos (Q12b). A pedido's items come back when its
# row is opened. Painel 2/4b: the blocks in time, the previsão and each
# sector's queue (FilaDeProducao); the page refreshes itself when the queue
# changes (CanaisAoVivo.avisar_fila). Painel 2/4c: the Linha do tempo, the
# second view, its window and order in the address (Q3a, Q6a). Painel 3/4b:
# what the photos of the turnos programmed — "veio de · adiada", the load
# over 100% — and the warning of who came to be late at the virada.
# Painel 3/4b2: each stage's first plan and who crossed each pedido, in the faixa.
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
    pedidos = @painel.linhas.flat_map(&:com_reposicoes).map(&:pedido)
    @historicos = historicos_da_programacao(pedidos.map(&:id))
    @planos = visiveis(PlanoDaEtapa).where(pedido: pedidos).group_by(&:pedido_id)
    @cruzamentos = CruzamentosDoPedido.call(pedidos, historicos: @historicos, viradas: visiveis(ViradaDoPedido), visiveis: visiveis(Pedido))
    # Painel 3/4b: the photos (none for a cliente final) and the virada's warning.
    @programado = ProgramadoNaFila.new(visiveis(FotoDaFila), @painel.fila)
    @atrasaram_na_virada = visiveis(ViradaDoPedido).do_turno_de(Time.current).atrasaram
                                                   .where(pedido: visiveis(Pedido).ativos).includes(:pedido).order(:id).to_a
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

  # Its moves and its viradas, by time (3/4b).
  def historicos_da_programacao(ids)
    movimentos = visiveis(MovimentoDaFila).por_pedido(ids)
    viradas = visiveis(ViradaDoPedido).where(pedido_id: ids).group_by(&:pedido_id)
    ids.index_with { |id| (movimentos.fetch(id) + viradas.fetch(id, [])).sort_by(&:created_at) }
  end

  def colunas_pedidas
    LinhaDoPainel::COLUNAS.slice(*Array(params[:colunas]))
  end
end
