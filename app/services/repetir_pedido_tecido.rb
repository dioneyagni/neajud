# Repeats a tecido pedido (decided 20/10/2026, from the "repetir pedido"
# screens of the cor lisa canvas): a new draft of the same client, with the
# same artes on the same fabrics and widths, the meters chosen this time (0
# leaves an item out), the fabric's owner and the paper of the original —
# and its prices: what the original charged comes as each item's edited
# price, so the client keeps what he paid; one below today's starting price
# is warned on the draft (PrecosDoItemTecido#precos_abaixo_do_valor), never
# blocked. Confirming writes the new starting prices as usual.
# An arte in the trash can't go into a new pedido (ReferenciaAtiva): it is
# left out and named.
#
# Invalid meters (more than one decimal) raise ActiveRecord::RecordInvalid,
# naming the item, and nothing is created.
#
# Usage: resultado = RepetirPedidoTecido.call(pedido, metros: { item.uuid => "24" }, pedidos: visiveis(Pedido))
#        resultado.pedido    # => the new draft
#        resultado.de_fora   # => ["CL-12 · Azul"] (artes in the trash)
class RepetirPedidoTecido
  Resultado = Struct.new(:pedido, :de_fora, keyword_init: true)
  REPETIVEIS = %w[confirmado em_producao entregue].freeze

  class NaoRepetivel < StandardError; end

  # pedidos: the visible scope the draft is created in (Visibilidade).
  def self.call(origem, metros:, pedidos:)
    new(origem, metros, pedidos).call
  end

  # Why a pedido can't be repeated, or nil.
  # Usage: RepetirPedidoTecido.erro(pedido) # => "Only a confirmed tecido pedido is repeated; this one is rascunho"
  def self.erro(pedido)
    return "Only a tecido pedido is repeated; this one is #{pedido.tipo}" unless pedido.tecido?
    return "#{pedido.rotulo_lixeira} is in the trash" if pedido.excluido?
    return "Only a confirmed tecido pedido is repeated (#{REPETIVEIS.join(", ")}); this one is #{pedido.status}" unless REPETIVEIS.include?(pedido.status)

    "A reposição is not repeated: repeat its pedido" if pedido.reposicao?
  end

  def initialize(origem, metros, pedidos)
    @origem = origem
    @metros = metros.to_h.transform_keys(&:to_s)
    @pedidos = pedidos
  end

  def call
    erro = self.class.erro(@origem)
    raise NaoRepetivel, erro if erro
    raise NaoRepetivel, "Nothing to repeat: every item is at 0 m" if itens.none? { |_, metros| metros.to_d.positive? }

    Pedido.transaction do
      novo = @pedidos.create!(status: "rascunho", tipo: "tecido", client: @origem.client, dono_tecido: @origem.dono_tecido,
                              material_impressao: @origem.material_impressao)
      de_fora = itens.filter_map { |item, metros| copiar(item, metros, novo) }
      Resultado.new(pedido: novo, de_fora: de_fora)
    end
  end

  private

  # The original's items with the meters asked ("24.5", as NumeroDigitado
  # gives them; blank = 0), the same when not asked.
  def itens
    @itens ||= @origem.itens_pedido.includes(:arte, :arquivo, :materia_prima).order(:id).map do |item|
      [ item, @metros.key?(item.uuid) ? @metros[item.uuid].to_s : item.metros ]
    end
  end

  # nil when copied (or left out at 0 m); the arte's name when in the trash.
  def copiar(item, metros, novo)
    return nil unless metros.to_d.positive?
    return item.arte.titulo if item.arquivo.excluido?

    novo.itens_pedido.create!(arquivo: item.arquivo, materia_prima: item.materia_prima, metros: metros, largura_mm: item.largura_mm,
                              preco_impressao_metro: item.preco_impressao_efetivo,
                              preco_tecido_metro: (item.preco_tecido_efetivo if item.cobra_tecido?))
    nil
  end
end
