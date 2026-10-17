# What keeps a tecido draft from being confirmed (Etapa 2.7a, decided
# 16/10/2026), in PedidoBloqueiosService's shape:
#   :pedido_sem_cliente, :arte_de_outro_cliente — the client is the
#                 pedido's (BloqueiosDoClienteDoPedido), as the DTF's;
#   :sem_material — an item without the fabric it is printed on;
#   :zerado     — an item without meters;
#   :sem_largura — neither a width typed on the item nor one read from its
#                 material ("1,60 m"): the RIP needs it.
# Wider than the paper is a warning on the item, never a block (decided
# 16/10/2026: the factory may have a wider paper) — avisos_de_largura.
# Nothing here splits the pedido by client.
#
# Usage: PedidoBloqueiosTecido.call(pedido).map(&:descricao)
class PedidoBloqueiosTecido
  include BloqueiosDoClienteDoPedido

  Bloqueio = PedidoBloqueiosService::Bloqueio

  def self.call(pedido)
    new(pedido).call
  end

  def initialize(pedido)
    @pedido = pedido
  end

  def call
    sem_cliente + de_outro_cliente("Arte") + sem_material + zerados + sem_largura
  end

  private

  def itens
    @itens ||= @pedido.itens_pedido.includes(:arquivo, :arte, :materia_prima).order(:id).to_a
  end

  def sem_material
    itens.reject(&:materia_prima).map { |item| bloqueio(:sem_material, item, "sem tecido: escolha o material") }
  end

  def zerados
    itens.reject { |item| item.metros.to_d.positive? }.map { |item| bloqueio(:zerado, item, "com 0 m: informe os metros") }
  end

  def sem_largura
    itens.select { |item| item.materia_prima && item.largura_efetiva_mm.nil? }.map do |item|
      bloqueio(:sem_largura, item, "sem largura: o material #{item.materia_prima.nome_completo} não diz a largura; informe-a no item")
    end
  end

  def bloqueio(tipo, item, texto)
    Bloqueio.new(tipo: tipo, descricao: "#{item.arte.titulo} #{texto}", arquivo: item.arquivo)
  end
end
