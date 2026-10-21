# Adjusts the stock by a baixa's real metragem (Etapa 2.3e, decided
# 20/10/2026): per material, the real (the baixa's measure of it — one per
# material when it covers several, BaixaProducao#medida_de) minus what its
# lines expected, split between the owners by their share of the expected
# (by pieces when the lines have none), the rounding left on the last. Used
# more: an out of the difference; less: an entry; the same: nothing. Each
# movement points at the pedido and the baixa, so undoing the baixa stops it
# counting (MovimentoEstoque.que_contam).
#
# Only a material × owner the pedido took at confirmation is adjusted
# (decided 20/10/2026): one confirmed before Etapa 2.3d2 took nothing, and an
# adjustment alone would leave the balance wrong.
#
# Usage: AjusteDaBaixa.call(baixa, linhas) # => [#<MovimentoEstoque tipo="saida" quantidade=1.2 …>]
class AjusteDaBaixa
  def self.call(baixa, linhas)
    new(baixa, linhas).call
  end

  def initialize(baixa, linhas)
    @baixa = baixa
    @pedido = baixa.pedido
    @etapa = EtapasProducao.etapa(@pedido.tipo, baixa.etapa, pedido: @pedido)
    @linhas = linhas
  end

  def call
    MateriaisDasLinhas.call(@pedido, @etapa, @linhas).group_by(&:materia_prima).flat_map do |material, partes|
      diferenca = @baixa.medida_de(material) - partes.sum(&:esperado).to_d
      diferenca.zero? ? [] : lancar(partes, diferenca)
    end
  end

  private

  def lancar(partes, diferenca)
    cotas(partes, diferenca).filter_map do |parte, metros|
      next unless metros.nonzero? && saiu_na_confirmacao?(parte)

      @pedido.movimentos_estoque.create!(materia_prima: parte.materia_prima, client: parte.client, da_empresa: parte.client.nil?, baixa_producao: @baixa,
                                         tipo: metros.positive? ? "saida" : "entrada", quantidade: metros.abs)
    end
  end

  # Each owner's share of the difference; the last takes what rounding left.
  def cotas(partes, diferenca)
    pesos = partes.map(&:esperado).sum.positive? ? partes.map { |p| p.esperado.to_d } : partes.map { |p| p.pecas.to_d }
    total = pesos.sum
    metros = pesos.map { |peso| total.positive? ? (diferenca * peso / total).round(4) : 0 }
    metros[-1] = diferenca - metros[0...-1].sum if total.positive?
    partes.zip(metros)
  end

  def saiu_na_confirmacao?(parte)
    @saidas ||= @pedido.movimentos_estoque.da_confirmacao.pluck(:materia_prima_id, :client_id).to_set
    @saidas.include?([ parte.materia_prima.id, parte.client&.id ])
  end
end
