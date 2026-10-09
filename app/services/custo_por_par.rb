# What one pair of an arte costs to make, per number (Etapa 2.4, decided
# 09/10/2026): the meters of paper its files take — each checked part's file
# for that number × its pieces per pair (a side's file half of them) — at the
# dono's printing cost per meter, plus the pieces that go to the cutting
# table at the cost per piece. A step towards the price calculator: the
# meters are only the way to the cost per pair.
#
# A number whose file is missing (a pendência) or has no meters yet (no DPI,
# still processing) is `incompleto`: its cost counts what is known, and
# `faltas` says what is missing per part (shown next to the "*").
#
# Usage: CustoPorPar.call(item, empresa: Empresa.atual)["30"].total # => 2.37
#        CustoPorPar.da_arte(arquivo, empresa: Empresa.atual)        # every number of the arte, before any pedido
class CustoPorPar
  # motivo: :sem_corte, :sem_arquivo, :sem_lado (ResolucaoDoItem) or
  # :sem_medida (a file without its size on the paper).
  Falta = Struct.new(:peca, :motivo, keyword_init: true)
  Custo = Struct.new(:numero, :impressao, :corte, :faltas, keyword_init: true) do
    def total
      impressao + corte
    end

    def incompleto
      faltas.any?
    end
  end

  def self.call(item, empresa:)
    new(item, empresa).call
  end

  # The arte's cost per pair for each number a pedido may ask, from a
  # pedido item built in memory (never saved), one pair of each.
  def self.da_arte(arquivo, empresa:)
    item = ItemPedido.new(arquivo: arquivo, arte: arquivo.arte)
    arquivo.arte.tamanhos_do_pedido.each { |numero| item.grades.build(tamanho_nome: numero, quantidade: 1) }
    MoldeComposicaoService.call(arquivo).each_with_index do |slot, position|
      item.item_pedido_pecas.build(peca: slot.peca, arquivo: slot.arquivo, position: position, incluida: true)
    end
    call(item, empresa: empresa)
  end

  def initialize(item, empresa)
    @item = item
    @empresa = empresa
  end

  def call
    custos = Hash.new { |hash, numero| hash[numero] = Custo.new(numero: numero, impressao: 0.to_d, corte: 0.to_d, faltas: []) }
    ResolucaoDoItem.call(@item).select(&:incluida).each do |parte|
      parte.numeros.each { |numero| somar(custos[numero.numero], parte, numero) }
    end
    custos.to_h
  end

  private

  def somar(custo, parte, numero)
    config = parte.config
    custo.corte += config[:pecas_por_par] * @empresa.custo_corte_peca.to_d if config[:needs_cut]
    impressos(config, numero).each do |arquivo, pecas|
      metros = arquivo&.approved_version&.metros_por_peca(@empresa.largura_papel_efetiva_mm)
      next custo.faltas << Falta.new(peca: parte.peca, motivo: arquivo ? :sem_medida : numero.pendencia) unless metros

      custo.impressao += metros.to_d * pecas * @empresa.custo_impressao_metro.to_d
    end
    custo.faltas.uniq!
  end

  # [[file, pieces per pair]]: each side's file prints half the pieces.
  def impressos(config, numero)
    return [ [ numero.arquivo, config[:pecas_por_par] ] ] unless numero.lados

    numero.lados.values.map { |arquivo| [ arquivo, config[:pecas_por_par] / 2.0 ] }
  end
end
