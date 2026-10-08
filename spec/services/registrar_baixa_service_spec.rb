require "rails_helper"

# Etapa 2.2 (2/3, decided 07/10/2026): the factory's baixa of each stage —
# granular, warned against what the files expect, locked where it can't
# physically happen yet.
RSpec.describe RegistrarBaixaService do
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:lingua) { create(:peca, nome: "Língua") }
  let(:molde) { create(:molde, partes: [ lateral, lingua ]) }
  let(:material) { MateriaPrima.create!(grupo_material: GrupoMaterial.create!(nome: "Tactel"), cor_material: CorMaterial.create!(nome: "Azul"), largura: "1.40 m", gramatura: "80g") }
  let(:pedido) { create(:pedido, status: "confirmado") }
  let(:usuario) { create(:user) }

  def corte(peca, metros)
    create(:arquivo, :corte, organized: true, peca: peca, client: molde.client, modelo: molde.modelo, giro: "180").tap do |c|
      c.moldes << molde
      create(:tamanho, arquivo: c, nome: "29-30", numeros: %w[29 30], position: 1, metros_por_peca: { "1400" => metros })
    end
  end

  # One arte (Lateral + Língua files of 29-30), 30 × 5 pairs: 10 pieces per part.
  let!(:item) do
    lat = corte(lateral, 0.02)
    lin = corte(lingua, 0.01)
    arte = create(:arquivo, molde: molde, client: molde.client, peca: lateral, tamanho: lat.tamanhos.first)
    create(:arquivo, arte: arte.arte, molde: molde, client: molde.client, peca: lingua, tamanho: lin.tamanhos.first)
    create(:item_pedido, pedido: pedido, arquivo: arte, materia_prima: material).tap do |i|
      i.compor_pecas!(MoldeComposicaoService.call(arte))
      i.grades.create!(tamanho_nome: "30", quantidade: 5)
    end
  end

  def baixa(etapa, nivel: "pedido", medida:, alvo: nil, confirmar: false)
    described_class.call(pedido, etapa: etapa, nivel: nivel, alvo: alvo, medida: medida, confirmar: confirmar, user: usuario, changed_by: "1.2.3.4")
  end

  def situacao(etapa)
    described_class.situacao(pedido, etapa).values.map { |s| [ s.linha.peca.nome, s.estado, s.aguardando ] }
  end

  it "takes the whole pedido's Corte against the fit: 10 pieces × 0,02 + 10 × 0,01 = 0,3 m" do
    resultado = baixa("corte", medida: "0,31")
    expect([ resultado.estado, resultado.baixa.esperado.to_f, resultado.baixa.linhas.size, resultado.baixa.user ]).to eq([ :ok, 0.3, 2, usuario ])
    expect(situacao("corte").map { |_, estado, _| estado }).to eq(%i[feita feita])
  end

  it "warns outside the dono's band and saves only once confirmed, marked" do
    abaixo = baixa("corte", medida: "0,2")
    expect([ abaixo.estado, abaixo.mensagem ]).to eq([ :aviso, "Esperado ~0,30 m, você informou 0,2 m. Confira e corrija, ou confirme assim mesmo." ])
    expect(pedido.baixas_producao).to be_empty
    expect(baixa("corte", medida: "0,2", confirmar: true).baixa.fora_da_faixa).to be true
  end

  it "warns well above the expected too (98 typed for 9,8)" do
    expect(baixa("corte", medida: "3").estado).to eq(:aviso)
  end

  it "gives one line, and a bigger level covers only the open ones" do
    linha = described_class.situacao(pedido, "corte").keys.first
    baixa("corte", nivel: "linha", alvo: linha, medida: "0,2")
    resto = baixa("corte", medida: "0,1")
    expect([ resto.estado, resto.baixa.linhas, resto.esperado ]).to eq([ :ok, described_class.situacao(pedido, "corte").keys - [ linha ], 0.1 ])
    expect(baixa("corte", medida: "1").mensagem).to start_with("Nothing open to give Corte's baixa")
  end

  # Decided 07/10/2026: without paper printed and pieces cut there's nothing to stamp.
  it "locks the Estamparia on the Impressão and the Corte of each line" do
    expect(situacao("estamparia")).to eq([ [ "Lateral", :aguardando, "Impressão" ], [ "Língua", :aguardando, "Impressão" ] ])
    baixa("impressao", medida: "0", confirmar: true)
    expect(situacao("estamparia").map(&:last)).to eq(%w[Corte Corte])
    linha = described_class.situacao(pedido, "estamparia").keys.first
    expect(baixa("estamparia", nivel: "linha", alvo: linha, medida: "10").mensagem).to eq("Waiting for Corte: this line can't have its Estamparia baixa yet.")
    baixa("corte", medida: "0,3")
    expect(baixa("estamparia", medida: "20").estado).to eq(:ok)
    expect(situacao("conferencia").map { |_, estado, _| estado }).to eq(%i[aberta aberta])
  end

  it "doesn't wait for the Corte of a part that doesn't cut" do
    molde.molde_pecas.find_by(peca: lingua).update!(needs_cut: false)
    baixa("impressao", medida: "0", confirmar: true)
    expect(situacao("estamparia")).to eq([ [ "Lateral", :aguardando, "Corte" ], [ "Língua", :aberta, nil ] ])
  end

  it "takes a referência: the arte's open lines" do
    resultado = baixa("impressao", nivel: "referencia", alvo: item.uuid, medida: "0", confirmar: true)
    expect(resultado.baixa.linhas.size).to eq(2)
  end

  it "refuses a draft, a level the stage doesn't take, and a measure that isn't a number" do
    expect(baixa("corte", nivel: "referencia", alvo: item.uuid, medida: "1").mensagem).to eq('Corte takes no baixa by "referencia"; expected one of linha, pedido.')
    expect(baixa("corte", medida: "doze").mensagem).to eq('Measure "doze" is not a number of meters.')
    pedido.update!(status: "rascunho")
    expect(baixa("corte", medida: "1").mensagem).to eq("This pedido is rascunho: only a confirmed pedido takes baixas.")
  end

  it "raises on a stage the pedido type doesn't have, naming it" do
    expect { baixa("costura", medida: "1") }.to raise_error(EtapasProducao::Invalida, /unknown production stage "costura"/)
  end
end
