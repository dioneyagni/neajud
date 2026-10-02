# Everything that keeps a draft pedido from being confirmed, one entry per
# problem, in the order the user fixes them:
#   :sem_arte   — a piece with no arte yet (pending);
#   :zerado     — an item whose total quantity is 0 (d7b86d8a was confirmed
#                 like this, Sep 2026);
#   :sem_corte  — a checked piece whose arte has no corte (no tamanho chosen),
#                 so production would have nothing to cut;
#   :tamanho_sem_corte — a size the pedido asks for that the piece's corte
#                 doesn't have, so there is no DXF to download for it;
#   :arquivo_excluido — the item's arte, or a checked piece's arte or corte,
#                 is in the trash (Etapa 0.4): restore it or swap it first;
#   :arte_sem_cliente — the item's arte has no client: confirming splits the
#                 pedido by its artes' clients, and ed6a2aba (01/10/2026)
#                 would have been confirmed without one.
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
    arquivos_excluidos + artes_sem_cliente + sem_arte + zerados + sem_corte + tamanhos_sem_corte
  end

  private

  def itens
    @itens ||= @pedido.itens_pedido.includes(:grades, :arquivo, item_pedido_pecas: [ :peca, { arquivo: { tamanho: :arquivo } } ]).order(:id).to_a
  end

  def arquivos_excluidos
    arquivos_usados.select(&:excluido?).map do |arquivo|
      Bloqueio.new(tipo: :arquivo_excluido, descricao: "#{arquivo.filename} está na lixeira", arquivo: arquivo)
    end
  end

  # Every arquivo production would read: the item's arte, and each checked
  # piece's arte and corte.
  def arquivos_usados
    itens.flat_map do |item|
      incluidas = item.item_pedido_pecas.select { |p| p.estado == :incluida }
      [ item.arquivo ] + incluidas.flat_map { |p| [ p.arquivo, p.arquivo.corte ] }
    end.compact.uniq
  end

  def artes_sem_cliente
    itens.map(&:arquivo).uniq.select { |arte| arte.client_id.nil? }.map do |arte|
      Bloqueio.new(tipo: :arte_sem_cliente, descricao: "Arte #{arte.filename} sem cliente", arquivo: arte)
    end
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

  def tamanhos_sem_corte
    ProducaoPedidoService.call(@pedido).flat_map do |linha|
      linha.tamanhos_faltando.map do |tamanho|
        Bloqueio.new(tipo: :tamanho_sem_corte, arquivo: linha.corte,
                     descricao: "#{linha.peca&.nome || "Sem peça"} #{tamanho_label(tamanho)}: tamanho não existe no corte #{linha.corte.filename}")
      end
    end
  end

  def tamanho_label(tamanho)
    tamanho == ProducaoPedidoService::TOTAL_KEY ? "(sem tamanho na arte)" : tamanho
  end

  def nome_peca(peca_row)
    peca_row.peca&.nome || "Sem peça"
  end
end
