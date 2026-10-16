# What keeps a DTF draft from being confirmed (Etapa 2.6b1, decided
# 13/10/2026), in PedidoBloqueiosService's shape:
#   :pedido_sem_cliente — the client is the pedido's, not the etiqueta's (D4):
#                 the team picks it on the pedido page;
#   :etiqueta_de_outro_cliente — an etiqueta outside the catálogo belongs to
#                 another client, or to none;
#   :zerado     — an item whose total quantity is 0;
#   :tamanho_sem_arquivo — a size ordered that has no active file;
#   :sem_medida — the size's file has no size or DPI: no fit on the film;
#   :nao_cabe   — the size is wider than the film's useful width both ways;
#   :nao_cabe_em_pe / :nao_cabe_girada — it fits only the other way than
#                 the etiqueta's "turn" mark (decided 16/10/2026): the team
#                 marks or unmarks it on the arte's page;
#   :sem_preco_dtf — something to charge has no price (Etapa 2.6c): a line,
#                 the meter or the cut, nowhere in the cascade — confirming
#                 writes the prices, so it would never have one.
# Unlike calçado, nothing here splits the pedido by client.
#
# Usage: PedidoBloqueiosDtf.call(pedido).map(&:descricao)
class PedidoBloqueiosDtf
  Bloqueio = PedidoBloqueiosService::Bloqueio
  DESCRICOES_DO_ENCAIXE = {
    sem_arquivo: [ :tamanho_sem_arquivo, "sem arquivo ativo desse tamanho" ],
    sem_medida: [ :sem_medida, "sem medida (o arquivo não tem tamanho ou DPI)" ],
    nao_cabe: [ :nao_cabe, "não cabe no filme nem girada" ],
    nao_cabe_em_pe: [ :nao_cabe_em_pe, "não cabe em pé no filme: marque Girar 90° na etiqueta" ],
    nao_cabe_girada: [ :nao_cabe_girada, "não cabe girada no filme: desmarque Girar 90° na etiqueta" ]
  }.freeze

  def self.call(pedido)
    new(pedido).call
  end

  def initialize(pedido)
    @pedido = pedido
  end

  def call
    sem_cliente + de_outro_cliente + zerados + do_encaixe + sem_preco
  end

  private

  def itens
    @itens ||= @pedido.itens_pedido.includes(:grades, :arquivo, :arte).order(:id).to_a
  end

  def sem_cliente
    return [] if @pedido.client_id

    [ Bloqueio.new(tipo: :pedido_sem_cliente, descricao: "Pedido sem cliente: escolha o cliente do pedido") ]
  end

  def de_outro_cliente
    itens.reject { |item| item.arte.no_catalogo || item.arquivo.client_id == @pedido.client_id }.uniq(&:arte_id).map do |item|
      dono = item.arquivo.client&.name
      descricao = dono ? "Etiqueta #{item.arte.titulo} é de #{dono}, não do cliente do pedido" : "Etiqueta #{item.arte.titulo} sem cliente: escolha um, ou marque Entra no catálogo"
      Bloqueio.new(tipo: :etiqueta_de_outro_cliente, descricao: descricao, arquivo: item.arquivo)
    end
  end

  def zerados
    itens.select { |item| item.grades.sum(&:quantidade).zero? }.map do |item|
      Bloqueio.new(tipo: :zerado, descricao: "Item #{item.arte.titulo} com quantidade total 0", arquivo: item.arquivo)
    end
  end

  def sem_preco
    ValoresDoPedidoDtf.call(@pedido).faltas.map do |parte|
      Bloqueio.new(tipo: :sem_preco_dtf, descricao: "#{parte.descricao} sem preço: defina o preço do DTF nos Parâmetros, no cliente ou na etiqueta", arquivo: parte.linha&.arquivo)
    end
  end

  def do_encaixe
    EncaixeDoPedidoDtf.call(@pedido).select(&:pendencia).map do |linha|
      tipo, texto = DESCRICOES_DO_ENCAIXE.fetch(linha.pendencia)
      tamanho = linha.grade.tamanho_nome == ProducaoPedidoService::TOTAL_KEY ? "" : " #{linha.grade.tamanho_nome}"
      Bloqueio.new(tipo: tipo, descricao: "#{linha.item.arte.titulo}#{tamanho} (#{linha.pedidas}): #{texto}", arquivo: linha.arquivo || linha.item.arquivo)
    end
  end
end
