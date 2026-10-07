# Everything that keeps a draft pedido from being confirmed, one entry per
# problem, in the order the user fixes them:
#   :arquivo_excluido — the item's arte, or a file or DXF production would
#                 read, is in the trash (Etapa 0.4): restore it or swap it first;
#   :arte_sem_cliente — the item's arte has no client: confirming splits the
#                 pedido by its artes' clients, and ed6a2aba (01/10/2026)
#                 would have been confirmed without one;
#   :zerado     — an item whose total quantity is 0 (d7b86d8a was confirmed
#                 like this, Sep 2026);
#   :sem_corte  — a number of a checked part that no organized DXF of the
#                 part serves (Etapa 1.2, 3/3: ResolucaoDoItem);
#   :sem_arquivo — a number the DXF serves but the arte has no file for (nor a
#                 piloto that covers it as a sample);
#   :sem_lado   — a mirrored part has that size's file of one side only
#                 (Etapa 1.2, 3/3 parte 3c).
# Unchecked parts never block: the pedido goes to production without them.
# Used by the confirm guard (server), the pending box and the list badge.
#
# Usage: PedidoBloqueiosService.call(pedido).map(&:descricao)
#   # => ["Língua 33-34 (33×4, 34×2) sem arquivo de produção na arte 001-TNS · 20 · Bluey"]
class PedidoBloqueiosService
  # tamanho: the DXF size missing a file (what "Enviar arquivo" fills);
  # lado: the side missing, for :sem_lado.
  Bloqueio = Struct.new(:tipo, :descricao, :arquivo, :tamanho, :lado, keyword_init: true)

  def self.call(pedido)
    new(pedido).call
  end

  def initialize(pedido)
    @pedido = pedido
  end

  def call
    arquivos_excluidos + artes_sem_cliente + zerados + pendencias_das_partes
  end

  private

  def itens
    @itens ||= @pedido.itens_pedido.includes(:grades, :arte, :arquivo, item_pedido_pecas: :peca).order(:id).to_a
  end

  def resolucoes
    @resolucoes ||= itens.to_h { |item| [ item, ResolucaoDoItem.call(item) ] }
  end

  def arquivos_excluidos
    arquivos_usados.select(&:excluido?).map do |arquivo|
      Bloqueio.new(tipo: :arquivo_excluido, descricao: "#{arquivo.filename} está na lixeira", arquivo: arquivo)
    end
  end

  # Every arquivo production would read: the item's file, and for each checked
  # part the arte's file and the DXF of each ordered number.
  def arquivos_usados
    resolucoes.flat_map do |item, partes|
      numeros = partes.select(&:incluida).flat_map(&:numeros)
      [ item.arquivo ] + numeros.flat_map { |n| [ n.arquivo, n.tamanho&.arquivo ] }
    end.compact.uniq
  end

  def artes_sem_cliente
    itens.map(&:arquivo).uniq.select { |arte| arte.client_id.nil? }.map do |arte|
      Bloqueio.new(tipo: :arte_sem_cliente, descricao: "Arte #{arte.filename} sem cliente", arquivo: arte)
    end
  end

  def zerados
    itens.select { |item| item.grades.sum(&:quantidade).zero? }.map do |item|
      Bloqueio.new(tipo: :zerado, descricao: "Item #{titulo(item)} com quantidade total 0", arquivo: item.arquivo)
    end
  end

  # One entry per part × DXF size missing (Etapa 1.2, 3/3 parte 3a): one
  # "Enviar arquivo" settles every number of that size.
  def pendencias_das_partes
    resolucoes.flat_map do |item, partes|
      partes.select(&:incluida).flat_map do |parte|
        parte.pendencias.group_by { |n| [ n.pendencia, n.tamanho, n.lado_faltando ] }.map { |_, numeros| bloqueio_dos_numeros(item, parte, numeros) }
      end
    end
  end

  def bloqueio_dos_numeros(item, parte, numeros)
    peca = parte.peca&.nome || "Sem peça"
    pedidos = numeros.map { |n| "#{rotulo(n.numero)}×#{n.quantidade}" }.join(", ")
    tamanho = numeros.first.tamanho
    case numeros.first.pendencia
    when :sem_corte
      Bloqueio.new(tipo: :sem_corte, arquivo: item.arquivo, descricao: "#{peca} #{pedidos}: nenhum corte organizado atende (arte #{titulo(item)})")
    when :sem_lado
      lado = numeros.first.lado_faltando
      Bloqueio.new(tipo: :sem_lado, arquivo: item.arquivo, tamanho: tamanho, lado: lado,
                   descricao: "#{peca} #{tamanho.nome} (#{pedidos}) sem o arquivo #{LadoNaArte::ABREVIACOES[lado]} (#{lado}) na arte #{titulo(item)}")
    else
      Bloqueio.new(tipo: :sem_arquivo, arquivo: item.arquivo, tamanho: tamanho,
                   descricao: "#{peca} #{tamanho.nome} (#{pedidos}) sem arquivo de produção na arte #{titulo(item)}")
    end
  end

  def rotulo(numero)
    numero == ProducaoPedidoService::TOTAL_KEY ? "Qtd" : numero
  end

  def titulo(item)
    item.arte&.titulo.presence || item.arquivo.filename
  end
end
