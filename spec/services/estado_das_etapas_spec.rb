require "rails_helper"
require_relative "../support/producao_calcado"

# Painel 1/4 (04/11/2026): every stage of a pedido read once, the same
# states each stage's page computes alone.
RSpec.describe EstadoDasEtapas do
  let(:pedido) { pedido_calcado_confirmado(itens: 2) }

  def estados(mapa)
    mapa.transform_values { |situacoes| situacoes.transform_values { |s| [ s.estado, s.aguardando, s.baixa&.id ] } }
  end

  it "gives each stage the states RegistrarBaixaService.situacao gives it alone" do
    RegistrarBaixaService.call(pedido, etapa: "impressao", nivel: "pedido", medida: "0", confirmar: true)
    sozinhas = EtapasProducao.do_tipo("calcado").to_h { |e| [ e.chave, RegistrarBaixaService.situacao(pedido, e.chave) ] }

    expect(estados(described_class.call(pedido.reload))).to eq(estados(sozinhas))
    expect(described_class.call(pedido)["estamparia"].values.map(&:aguardando).uniq).to eq([ "Corte" ])
  end

  it "reads the baixas given and ignores an undone one" do
    baixa = RegistrarBaixaService.call(pedido, etapa: "corte", nivel: "pedido", medida: "0", confirmar: true).baixa
    expect(described_class.call(pedido, baixas: [ baixa ])["corte"].values.map(&:estado).uniq).to eq([ :feita ])

    baixa.update!(desfeita_em: Time.current)
    expect(described_class.call(pedido, baixas: [ baixa ])["corte"].values.map(&:estado).uniq).to eq([ :aberta ])
  end

  # Measured 04/11/2026: each stage rebuilt the lines (~1.200 queries for a
  # pedido of 6 items). Built once, a stage more costs no line query.
  it "builds the shared Impressão lines once for Impressão, Estamparia and Conferência" do
    chamadas = 0
    original = ImpressaoPedidoService.method(:call)
    allow(ImpressaoPedidoService).to receive(:call) { |*args| chamadas += 1; original.call(*args) }

    described_class.call(pedido)
    expect(chamadas).to eq(1)
  end
end
