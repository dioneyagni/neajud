# What a metragem stage's lines take from the stock (Etapa 2.3e, decided
# 20/10/2026): their expected meters per material × owner — what the baixa's
# real is measured against, per material, and split between owners by.
#   material impressao — the pedido's paper or DTF film, the empresa's;
#   material linha     — each line's fabric: a tecido line's item says the
#     owner; a Corte line may join items of different owners (one molde's
#     fabric is the client's, another's the empresa's), so its lines are
#     rebuilt per owner, as the stock out does (SaidaDoPedido).
# A line without material is left out (it took nothing from the stock); a
# fabric of "cliente" on a pedido without client has no owner, also out.
#
# Usage: MateriaisDasLinhas.call(pedido, etapa, linhas)
#   # => [#<Parte materia_prima=Oxford client=MKS esperado=10.0 pecas=40>, …]
#        MateriaisDasLinhas.por_material(pedido, etapa, linhas) # => { Oxford => 10.0, Helanca => 5.0 }
class MateriaisDasLinhas
  Parte = Struct.new(:materia_prima, :client, :esperado, :pecas, keyword_init: true)

  def self.call(pedido, etapa, linhas)
    new(pedido, etapa, linhas).call
  end

  # The expected meters of each material, owners summed (the baixa's fields).
  def self.por_material(pedido, etapa, linhas)
    call(pedido, etapa, linhas).group_by(&:materia_prima).transform_values { |partes| partes.sum(&:esperado) }
  end

  def initialize(pedido, etapa, linhas)
    @pedido = pedido
    @etapa = etapa
    @linhas = linhas
    @partes = {}
  end

  def call
    return [] unless @etapa.ajusta_estoque?

    if @etapa.material == "impressao" then do_material_de_impressao
    elsif @etapa.linhas == "corte" then do_corte_por_dono
    else do_item_de_cada_linha
    end
    @partes.values
  end

  private

  def do_material_de_impressao
    material = @pedido.material_de_impressao
    @linhas.each { |linha| somar(material, nil, linha.esperado, linha.pecas) } if material
  end

  # The Corte's lines again, one owner at a time, kept to the baixa's keys.
  def do_corte_por_dono
    chaves = @linhas.to_set(&:chave)
    DonoDoTecido.itens_por_dono(@pedido).each do |dono, itens|
      ProducaoPedidoService.call(@pedido, itens: itens).select(&:tamanho).each do |linha|
        next unless chaves.include?(LinhasDeProducao.chave_do_corte(linha.peca, linha.tamanho, linha.materia_prima))

        somar(linha.materia_prima, dono, linha.metros_esperados, linha.pecas)
      end
    end
  end

  def do_item_de_cada_linha
    @linhas.each { |linha| somar(linha.materia_prima, DonoDoTecido.do_item(linha.item).dono, linha.esperado, linha.pecas) }
  end

  # dono: "empresa", "cliente" or nil (already the empresa's: paper, film).
  def somar(material, dono, esperado, pecas)
    return unless material
    return if dono == "cliente" && !@pedido.client

    client = @pedido.client if dono == "cliente"
    parte = @partes[[ material.id, client&.id ]] ||= Parte.new(materia_prima: material, client: client, esperado: 0.0, pecas: 0)
    parte.esperado += esperado.to_f
    parte.pecas += pecas.to_i
  end
end
