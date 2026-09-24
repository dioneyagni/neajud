# Everything that keeps a draft pedido from being confirmed, one entry per
# problem, in the order the user fixes them:
#   :sem_arte   — a piece with no arte yet (pending);
#   :zerado     — an item whose total quantity is 0 (d7b86d8a was confirmed
#                 like this, Sep 2026);
#   :sem_corte  — a checked piece whose arte has no corte (no tamanho chosen),
#                 so production would have nothing to cut.
# Unchecked pieces never block: the pedido goes to production without them.
# Used by the confirm guard (server), the pending box and the list badge.
#
# Usage: PedidoBloqueiosService.call(pedido).map(&:descricao)
#   # => ["Língua sem arte (item tenis-baixo)", "Item tenis-baixo com quantidade total 0"]
class PedidoBloqueiosService
  Bloqueio = Struct.new(:tipo, :descricao, :arquivo, keyword_init: true)

  def self.call(pedido)
    new(pedido).call
  end

  def initialize(pedido)
    @pedido = pedido
  end

  def call
    sem_arte + zerados + sem_corte
  end

  private

  def itens
    @itens ||= @pedido.itens_pedido.includes(:grades, :arquivo, item_pedido_pecas: [ :peca, { arquivo: { tamanho: :arquivo } } ]).order(:id).to_a
  end

  def sem_arte
    itens.flat_map do |item|
      item.item_pedido_pecas.select { |p| p.estado == :pendente }.map do |peca_row|
        Bloqueio.new(tipo: :sem_arte, descricao: "#{nome_peca(peca_row)} sem arte (item #{item.arquivo.filename})", arquivo: item.arquivo)
      end
    end
  end

  def zerados
    itens.select { |item| item.grades.sum(&:quantidade).zero? }.map do |item|
      Bloqueio.new(tipo: :zerado, descricao: "Item #{item.arquivo.filename} com quantidade total 0", arquivo: item.arquivo)
    end
  end

  def sem_corte
    itens.flat_map do |item|
      item.item_pedido_pecas.select { |p| p.estado == :incluida && p.arquivo.corte.nil? }.map do |peca_row|
        Bloqueio.new(tipo: :sem_corte, descricao: "#{nome_peca(peca_row)} sem arquivo de corte (arte #{peca_row.arquivo.filename})", arquivo: peca_row.arquivo)
      end
    end
  end

  def nome_peca(peca_row)
    peca_row.peca&.nome || "Sem peça"
  end
end
