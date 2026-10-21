# The tecido pedidos' own list (decided 20/10/2026, the layout of the cor
# lisa canvas's "Sistema · pedidos"): cards per status that count and
# filter, a search, and a table with the arte's swatch or thumbnail, the
# fabrics, the meters, the value and "Repetir". Our statuses, not payment:
# selling in several steps (fabric, arte, dublagem) is its own later
# analysis. Every query goes through Visibilidade — a cliente final sees his
# own.
#
# Usage: GET /pedidos/tecido?status=entregue&q=floral (also ?aguardando=1)
class ListaPedidosTecidoController < ApplicationController
  exige :pedidos, :ver

  STATUS_DA_LISTA = %w[rascunho enviado confirmado em_producao entregue].freeze

  def index
    base = visiveis(Pedido).ativos.where(tipo: "tecido", reposicao_de_id: nil)
    @contagens = base.group(:status).count
    # AguardandoMaterialHelper reads the same instance variable.
    @aguardando_ids = (@aguardando_material = AguardandoMaterial.call).pedido_ids
    @contagens["aguardando"] = base.where(id: @aguardando_ids).count
    @status = params[:aguardando] == "1" ? "aguardando" : (params[:status] if STATUS_DA_LISTA.include?(params[:status]))
    @busca = params[:q].to_s.strip
    @pedidos = buscar(filtrar(base), @busca).includes(:client, itens_pedido: [ :materia_prima, { arte: :arquivos }, :arquivo ]).order(created_at: :desc)
  end

  private

  def filtrar(pedidos)
    return pedidos.where(id: @aguardando_ids) if @status == "aguardando"

    @status ? pedidos.where(status: @status) : pedidos
  end

  # The pedido's number (the start of its uuid), the client's name, an
  # arte's file name, a cor lisa's family or a work's number.
  def buscar(pedidos, busca)
    return pedidos if busca.blank?

    termo = "%#{Pedido.sanitize_sql_like(busca.downcase)}%"
    itens = ItemPedido.joins(:arquivo).left_joins(:arte)
                      .where("LOWER(arquivos.filename) LIKE :t OR LOWER(artes.familia) LIKE :t OR CAST(artes.numero AS TEXT) = :n", t: termo, n: busca.gsub(/\D/, ""))
    pedidos.left_joins(:client)
           .where("pedidos.uuid LIKE :inicio OR LOWER(clients.name) LIKE :t", inicio: "#{Pedido.sanitize_sql_like(busca.downcase)}%", t: termo)
           .or(pedidos.left_joins(:client).where(id: itens.select(:pedido_id)))
  end
end
