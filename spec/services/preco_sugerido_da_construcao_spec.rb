require "rails_helper"
require_relative "../support/construcoes"

RSpec.describe PrecoSugeridoDaConstrucao do
  let(:oxford) { material_de_dublagem("Oxford", cor: "Preto", preco: 20) }
  let(:lona) { material_de_dublagem("Lona", preco: 10) }
  let(:filme_35) { material_de_dublagem("Filme", tipo: "filme", micras: 35, preco: 3) }

  # D7: the empresa's layers, each ligante and the service per ligação.
  it "adds the layers, the ligantes and the service per ligação" do
    preco = described_class.new(montar_construcao([ oxford, "trama" ], [ lona, filme_35 ]), servico: 4)

    expect(preco.linhas.map { |linha| [ linha.rotulo, linha.valor ] }).to eq([
      [ "Oxford-Preto-1.40 m", 20 ], [ "Lona-Branco-1.40 m", 10 ], [ "Filme 35 µm-Branco-1.40 m (ligação 1)", 3 ], [ "Serviço × 1 ligação", 4 ]
    ])
    expect(preco.total).to eq(37)
    expect(preco.sem_preco).to be_empty
  end

  it "leaves the client's layers out" do
    preco = described_class.new(montar_construcao([ oxford, "trama", { do_cliente: true } ], [ lona, filme_35 ]), servico: 4)

    expect(preco.linhas.first).to have_attributes(rotulo: "Oxford-Preto-1.40 m", valor: nil, nota: "do cliente")
    expect(preco.total).to eq(17)
  end

  it "marks what has no price, adding nothing for it" do
    espuma = material_de_dublagem("Espuma", densidade: "TC4")
    preco = described_class.new(montar_construcao([ oxford, "trama" ], [ espuma, nil ]), servico: nil)

    expect(preco.sem_preco.map(&:rotulo)).to eq([ "Espuma TC4-Branco-1.40 m", "Serviço × 1 ligação" ])
    expect(preco.linhas[2]).to have_attributes(rotulo: "Ligante da ligação 1", nota: "sem ligante")
    expect(preco.total).to eq(20)
  end

  # Dublagem 5b1a: each dublagem's own lines — a letra used at its price —,
  # the last one's being the total.
  it "prices each dublagem of the chave, the earlier letra at its own price" do
    espuma = material_de_dublagem("Espuma", densidade: "TC4", preco: 18)
    construcao = montar_construcao([ oxford, "trama", { do_cliente: true } ], [ lona, filme_35 ], [ espuma, nil ])
    preco = described_class.new(construcao, servico: 2)
    dub_a, dub_b = construcao.chave.dublagens

    expect(preco.linhas_da_dublagem(dub_a).map { |linha| [ linha.rotulo, linha.valor, linha.nota ] })
      .to eq([ [ "Oxford Preto", nil, "do cliente" ], [ "Lona Branco", 10, nil ], [ "Filme 35 µm Branco", 3, nil ], [ "serviço", 2, nil ] ])
    expect(preco.linhas_da_dublagem(dub_b).map { |linha| [ linha.rotulo, linha.valor, linha.nota ] })
      .to eq([ [ "DUB-A", 15, nil ], [ "Espuma TC4 Branco", 18, nil ], [ "ligante", nil, "—" ], [ "serviço", 2, nil ] ])
    expect(preco.total_da_dublagem(dub_b)).to eq(preco.total)
  end
end
