require "rails_helper"
require_relative "../support/etiquetas_dtf"

# Etapa 2.6c (decided 13-14/10/2026): what a DTF pedido charges — by quantity
# or meter (D2), the unit price's cascade (D1, D4, D6), the edited prices with
# the starting ones beside (D3), the cut on every printed unit (D5).
RSpec.describe ValoresDoPedidoDtf do
  let(:client) { create(:client) }
  # P 100: turned, 4 rows of 30 → 120 printed (20 over), 0,0707 m; 0,07 a unit at R$ 120/m.
  # P 100 marked to turn (16/10/2026: only then it turns): 4 rows of 30 → 120
  # printed (20 over), 0,0707 m; 0,08 a unit at R$ 120/m (120 / 1697,8 turned).
  let!(:etiqueta) { criar_etiqueta_dtf(client: client, girar_dtf: true) }
  let(:pedido) { create(:pedido, client: client, tipo: "dtf") }
  let!(:item) do
    create(:item_pedido, pedido: pedido, arquivo: etiqueta.arquivos.first).tap { |i| i.grades.create!(tamanho_nome: "P", quantidade: 100) }
  end

  before { Empresa.atual.update!(preco_metro_dtf: 120, preco_corte_dtf: 0.05) }

  def valores
    described_class.call(pedido.reload)
  end

  def linha
    valores.partes.first
  end

  it "charges by quantity the printed units, the excess too by default; the client may say not" do
    expect(linha.to_h.slice(:quantidade, :preco_partida, :preco)).to eq(quantidade: 120, preco_partida: BigDecimal("0.08"), preco: BigDecimal("0.08"))
    expect(valores.total).to eq(9.6)
    client.update!(cobrar_excedente_dtf: false)
    expect([ linha.quantidade, valores.total ]).to eq([ 100, 8.0 ])
    pedido.update!(cobrar_excedente: true)
    expect(linha.quantidade).to eq(120)
  end

  it "takes the etiqueta's agreed price first, else the ordering client's price per meter" do
    etiqueta.arquivos.first.update!(preco_unidade_combinado: 0.05)
    expect(linha.preco_partida).to eq(BigDecimal("0.05"))
    etiqueta.arquivos.first.update!(preco_unidade_combinado: nil)
    outro = create(:client, preco_metro_dtf: 240)
    pedido.update!(client: outro)
    # 240 / 1697,8 = 0,1414 → 0,15, for this client only (the etiqueta keeps 0,08).
    expect([ linha.preco_partida, etiqueta.arquivos.first.reload.preco_unidade_calculado ]).to eq([ BigDecimal("0.15"), BigDecimal("0.08") ])
  end

  it "charges an edited price, measuring the discount on the starting one" do
    item.grades.first.update!(preco_unidade: 0.06)
    expect([ linha.preco, valores.total, valores.desconto ]).to eq([ BigDecimal("0.06"), 7.2, 2.4 ])
  end

  it "charges by meter the whole film, and the cut on every unit printed" do
    pedido.update!(cobranca_dtf: "metro", entrega: "cortada")
    expect(valores.partes.map { |p| [ p.descricao, p.quantidade, p.preco, p.subtotal ] }).to eq([ [ "Filme", 0.0707, BigDecimal("120"), 8.48 ], [ "Corte", 120, BigDecimal("0.05"), 6.0 ] ])
  end

  it "names what has no price" do
    Empresa.atual.update!(preco_metro_dtf: nil, preco_corte_dtf: nil)
    pedido.update!(entrega: "cortada")
    expect(valores.faltas.map(&:descricao)).to eq([ "#{etiqueta.titulo} P", "Corte" ])
  end

  # Decided 14/10/2026: each line's price sits in its etiqueta's table, and
  # "Valores do pedido" keeps only the etiquetas summed and the pedido's own.
  describe "the sums for the pedido page" do
    let!(:outra) { criar_etiqueta_dtf(client: client, girar_dtf: true) }
    let!(:outro_item) do
      create(:item_pedido, pedido: pedido, arquivo: outra.arquivos.first).tap { |i| i.grades.create!(tamanho_nome: "P", quantidade: 30, preco_unidade: 0.06) }
    end

    it "finds a line's charge, sums each etiqueta and all of them, apart from the cut" do
      pedido.update!(entrega: "cortada")
      atual = valores
      linha_do_outro = EncaixeDoPedidoDtf.call(pedido).find { |l| l.item == outro_item }
      # The other's 30 → 1 row of 30, at the edited 0,06 (starting 0,08).
      expect(atual.da_linha(linha_do_outro).to_h.slice(:quantidade, :preco)).to eq(quantidade: 30, preco: BigDecimal("0.06"))
      expect(atual.do_item(item).to_h).to eq(quantidade: 120, subtotal: 9.6, subtotal_partida: 9.6)
      expect(atual.das_etiquetas.to_h).to eq(quantidade: 150, subtotal: 11.4, subtotal_partida: 12.0)
      expect(atual.do_pedido.map(&:descricao)).to eq([ "Corte" ])
    end

    it "has no line charges by meter: the film is the pedido's" do
      pedido.update!(cobranca_dtf: "metro")
      expect([ valores.das_etiquetas, valores.da_linha(EncaixeDoPedidoDtf.call(pedido).first), valores.do_pedido.map(&:descricao) ]).to eq([ nil, nil, [ "Filme" ] ])
    end

    it "reuses the fit it is given" do
      linhas = EncaixeDoPedidoDtf.call(pedido)
      expect(EncaixeDoPedidoDtf).not_to receive(:call)
      expect(described_class.call(pedido, linhas: linhas).total).to eq(11.4)
    end
  end

  it "keeps what was confirmed, whatever the prices do next" do
    item.grades.first.update!(preco_unidade: 0.06)
    EncaixeDoPedidoDtf.gravar!(pedido)
    described_class.gravar!(pedido.reload)
    pedido.update!(status: "confirmado")
    Empresa.atual.update!(preco_metro_dtf: 300, cobrar_excedente_dtf: false)
    expect(linha.to_h.slice(:quantidade, :preco_partida, :preco)).to eq(quantidade: 120, preco_partida: BigDecimal("0.08"), preco: BigDecimal("0.06"))
    expect(pedido.reload.attributes.values_at("cobranca_dtf", "cobrar_excedente")).to eq([ "quantidade", true ])
  end
end
