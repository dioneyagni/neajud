require "rails_helper"
require_relative "../support/producao_calcado"

# Painel 1/4 (Q2a): an item's own lines per stage; the Corte is the pedido's.
RSpec.describe ItensDoPainel do
  it "gives each item its Impressão lines and the whole pedido's Corte" do
    pedido = pedido_calcado_confirmado(itens: 2)
    primeiro = pedido.itens_pedido.order(:id).first
    linha = RegistrarBaixaService.situacao(pedido, "impressao").values.find { |s| s.linha.referencia == primeiro.uuid }
    RegistrarBaixaService.call(pedido, etapa: "impressao", nivel: "linha", alvo: linha.linha.chave, medida: "0", confirmar: true)

    itens = described_class.call(pedido.reload)
    expect(itens.map { |i| i.celulas["impressao"].texto }).to eq([ "1/2", "pode começar" ])
    expect(itens.map { |i| i.celulas["corte"].total }).to eq([ 2, 2 ])
  end

  it "computes no stage for a draft" do
    rascunho = create(:pedido)
    expect(described_class.call(rascunho)).to eq([])
  end
end
