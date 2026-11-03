# What keeps a tecido draft from being confirmed (Etapa 2.7a, decided
# 16/10/2026), in PedidoBloqueiosService's shape:
#   :pedido_sem_cliente, :arte_de_outro_cliente — the client is the
#                 pedido's (BloqueiosDoClienteDoPedido), as the DTF's;
#   :sem_material — an item without the fabric it is printed on;
#   :zerado     — an item without meters;
#   :sem_largura — neither a width typed on the item nor one read from its
#                 material ("1,60 m"): the RIP needs it.
#   :abaixo_do_minimo — fewer meters than the dono's minimum per item, not
#                 approved for these meters (Etapa 2.7b, decided 17/10/2026):
#                 the client's (he may raise them), approved by the team with
#                 "aprovar abaixo do mínimo";
#   :sem_preco_impressao, :sem_preco_tecido — no print price per meter (the
#                 dono's, the client's or the item's), or the empresa's
#                 fabric without its price (2.7b): confirming writes them.
#   :construcao_nao_serve — the item's construção went to the trash, or no
#                 longer fits (its superfície isn't the item's, or the
#                 pedido's client changed) — Dublagem 4/5, the client's;
#   :sem_preco_dublado — a construção without its final price, the factory's.
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
    sem_cliente + de_outro_cliente("Arte") + sem_material + construcoes_que_nao_servem + zerados + sem_largura + abaixo_do_minimo + sem_preco
  end

  private

  def itens
    @itens ||= @pedido.itens_pedido.includes(:arquivo, :arte, :materia_prima, :construcao).order(:id).to_a
  end

  def sem_material
    itens.reject(&:materia_prima).map { |item| bloqueio(:sem_material, item, "sem tecido: escolha o material") }
  end

  def construcoes_que_nao_servem
    itens.filter_map do |item|
      motivo = item.construcao&.excluido? ? "está na lixeira" : item.motivo_da_construcao_que_nao_serve
      bloqueio(:construcao_nao_serve, item, "com a construção #{item.construcao.nome}, que não serve: #{motivo}; escolha outra") if motivo
    end
  end

  def zerados
    itens.reject { |item| item.metros.to_d.positive? }.map { |item| bloqueio(:zerado, item, "com 0 m: informe os metros") }
  end

  def sem_largura
    itens.select { |item| item.materia_prima && item.largura_efetiva_mm.nil? }.map do |item|
      bloqueio(:sem_largura, item, "sem largura: o material #{item.materia_prima.nome_completo} não diz a largura; informe-a no item")
    end
  end

  def abaixo_do_minimo
    itens.select { |item| item.abaixo_do_minimo? && !item.minimo_aprovado? }.map do |item|
      bloqueio(:abaixo_do_minimo, item, "abaixo do mínimo: #{metros(item.metros)} de #{metros(item.metragem_minima)}")
    end
  end

  def sem_preco
    valores = ValoresDoPedidoTecido.call(@pedido)
    valores.faltas.map do |falta|
      item = falta.linha
      if falta.descricao == "Impressão"
        Bloqueio.new(tipo: :sem_preco_impressao, descricao: "#{item.arte.titulo} sem preço da impressão por metro")
      elsif item.construcao
        Bloqueio.new(tipo: :sem_preco_dublado, descricao: "#{item.arte.titulo}: a construção #{item.construcao.nome} sem preço final", construcao: item.construcao)
      else
        Bloqueio.new(tipo: :sem_preco_tecido, descricao: "#{item.arte.titulo}: o tecido #{item.materia_prima&.nome_completo || "do item"} sem preço por metro")
      end
    end
  end

  def metros(valor)
    "#{valor.to_d.to_s("F").sub(/\.0\z/, "").tr(".", ",")} m"
  end

  def bloqueio(tipo, item, texto)
    Bloqueio.new(tipo: tipo, descricao: "#{item.arte.titulo} #{texto}", arquivo: item.arquivo)
  end
end
