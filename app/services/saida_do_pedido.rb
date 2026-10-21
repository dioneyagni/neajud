# What a pedido takes from the stock when it is confirmed (Etapa 2.3d2,
# decided 19/10/2026): its expected meters, one out per material × owner,
# pointing at the pedido (MovimentoEstoque#pedido):
#   calçado — the fabric of its Corte lines, from each item's owner
#     (DonoDoTecido: items of different moldes may differ), and the paper of
#     its Impressão lines, the empresa's; a released reposição the same for
#     the pieces it redoes (the owner of the item they came from);
#   tecido  — each item's meters, of its fabric (the item's owner) and of
#     the paper;
#   DTF     — the film's meters of the fit written at confirmation.
# A line without material or metragem takes nothing and comes back as a
# warning; it never blocks. Only once per pedido (decided 20/10/2026: pedidos
# confirmed before this stage took nothing, and won't).
#
# Usage: SaidaDoPedido.call(pedido) # => ["Corte: Lateral 29-30 has no fabric chosen"]
class SaidaDoPedido
  def self.call(pedido)
    new(pedido).call
  end

  def initialize(pedido)
    @pedido = pedido
    @metros = Hash.new(0)
    @avisos = []
  end

  # The warnings: what took nothing from the stock.
  def call
    return [] if @pedido.movimentos_estoque.exists?

    do_material_de_impressao
    @pedido.tecido? ? do_tecido_dos_itens : do_tecido_do_corte
    gravar!
    @avisos.uniq
  end

  private

  # The paper or the DTF film, always the empresa's.
  def do_material_de_impressao
    material = @pedido.material_de_impressao
    return @avisos << "Impressão: no #{@pedido.dtf? ? "DTF film" : "paper"} chosen and no default one in Parâmetros" unless material

    LinhasDeProducao.call(@pedido, EtapasProducao.etapa(@pedido.tipo, "impressao")).each do |linha|
      next @avisos << "Impressão: #{linha.arquivo&.filename} has no metragem (its size or DPI)" unless linha.esperado

      @metros[[ material, nil ]] += linha.esperado
    end
  end

  def do_tecido_do_corte
    return if @pedido.dtf?

    DonoDoTecido.itens_por_dono(@pedido).each do |dono, itens|
      ProducaoPedidoService.call(@pedido, itens: itens).select(&:tamanho).each { |linha| tecido_da_linha(linha, dono) }
    end
  end

  def tecido_da_linha(linha, dono)
    nome = "Corte: #{linha.peca&.nome} #{linha.tamanho.nome}".squish
    return @avisos << "#{nome} has no fabric chosen" unless linha.materia_prima
    return @avisos << "#{nome} has no metragem (the fabric's width or the size's fit)" unless linha.metros_esperados

    somar_do_dono(linha.materia_prima, dono, linha.metros_esperados)
  end

  def do_tecido_dos_itens
    LinhasDeProducao.call(@pedido, EtapasProducao.etapa("tecido", "calandra")).each do |linha|
      somar_do_dono(linha.materia_prima, DonoDoTecido.do_item(linha.item).dono, linha.esperado)
    end
  end

  def somar_do_dono(material, dono, metros)
    return @metros[[ material, nil ]] += metros if dono == "empresa"
    return @avisos << "#{material.nome_completo}: the fabric is the client's, but the pedido has no client" unless @pedido.client

    @metros[[ material, @pedido.client ]] += metros
  end

  def gravar!
    MovimentoEstoque.transaction do
      @metros.each do |(material, client), metros|
        next unless metros.positive?

        @pedido.movimentos_estoque.create!(materia_prima: material, client: client, da_empresa: client.nil?, tipo: "saida", quantidade: metros.round(4))
      end
    end
  end
end
