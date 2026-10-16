require "rails_helper"
require_relative "../support/etiquetas_dtf"

# Etapa 2.6c (decided 14/10/2026): each etiqueta size's unit price, calculated
# from the price per meter and its fit, rounded up to the cent, and kept up to
# date with them.
RSpec.describe PrecoDaEtiqueta do
  let(:client) { create(:client) }
  # P: 32 a row standing every 18,52 mm → 1727,9 a meter (turned: 1697,8).
  let!(:etiqueta) { criar_etiqueta_dtf(client: client) }
  let(:arquivo) { etiqueta.arquivos.first }

  it "divides the price per meter by the units a meter holds, rounding up to the cent" do
    expect(described_class.unidades_por_metro(arquivo.encaixe_dtf, "em_pe").round(1)).to eq(1727.9)
    expect(described_class.unidades_por_metro(arquivo.encaixe_dtf, "girada").round(1)).to eq(1697.8)
    # 120 / 1727,9 = 0,0694 → 0,07.
    expect(described_class.unitario(arquivo.encaixe_dtf, 120, "em_pe")).to eq(BigDecimal("0.07"))
    expect([ described_class.unitario(nil, 120, "em_pe"), described_class.unitario(arquivo.encaixe_dtf, nil, "em_pe") ]).to eq([ nil, nil ])
  end

  # 16/10/2026: the price follows the orientation the etiqueta goes, not the denser one.
  it "is calculated in the etiqueta's orientation, and follows its turn mark" do
    Empresa.atual.update!(preco_metro_dtf: 500)
    # 500 / 1727,9 = 0,2894 → 0,29 standing; 500 / 1697,8 = 0,2945 → 0,30 turned.
    expect(arquivo.reload.preco_unidade_calculado).to eq(BigDecimal("0.29"))
    etiqueta.update!(girar_dtf: true)
    expect(arquivo.reload.preco_unidade_calculado).to eq(BigDecimal("0.30"))
  end

  it "is stored from the dono's price per meter, then from the client's own, and follows them" do
    Empresa.atual.update!(preco_metro_dtf: 120)
    expect(arquivo.reload.preco_unidade_calculado).to eq(BigDecimal("0.07"))
    client.update!(preco_metro_dtf: 200)
    expect(arquivo.reload.preco_unidade_calculado).to eq(BigDecimal("0.12"))
    Empresa.atual.update!(preco_metro_dtf: 60)
    expect(arquivo.reload.preco_unidade_calculado).to eq(BigDecimal("0.12"))
  end

  # D4: a catálogo work's price is the same for everyone — the dono's.
  it "takes the dono's price for a catálogo etiqueta, whatever its client agreed" do
    Empresa.atual.update!(preco_metro_dtf: 120)
    client.update!(preco_metro_dtf: 200)
    etiqueta.update!(no_catalogo: true)
    expect(arquivo.reload.preco_unidade_calculado).to eq(BigDecimal("0.07"))
  end

  it "follows the etiqueta to another client" do
    Empresa.atual.update!(preco_metro_dtf: 120)
    arquivo.update!(client: create(:client, preco_metro_dtf: 240))
    expect(arquivo.reload.preco_unidade_calculado).to eq(BigDecimal("0.14"))
  end
end
