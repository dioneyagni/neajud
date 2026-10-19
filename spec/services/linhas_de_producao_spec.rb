require "rails_helper"
require_relative "../support/producao_tecido"

# Etapa 2.2 (2/3): each stage's lines with stable keys made of uuids.
RSpec.describe LinhasDeProducao do
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:lingua) { create(:peca, nome: "Língua") }
  let(:molde) { create(:molde, partes: [ lateral, lingua ]) }
  let(:material) { MateriaPrima.create!(grupo_material: GrupoMaterial.create!(nome: "Tactel"), cor_material: CorMaterial.create!(nome: "Azul"), largura: "1.40 m", gramatura: "80g") }
  let(:pedido) { create(:pedido, status: "confirmado") }

  let!(:item) do
    cortes = [ lateral, lingua ].map do |peca|
      create(:arquivo, :corte, organized: true, peca: peca, client: molde.client, modelo: molde.modelo, giro: "180").tap do |c|
        c.moldes << molde
        create(:tamanho, arquivo: c, nome: "29-30", numeros: %w[29 30], position: 1, metros_por_peca: { "1400" => 0.02 })
      end
    end
    arte = create(:arquivo, molde: molde, client: molde.client, peca: lateral, tamanho: cortes.first.tamanhos.first)
    create(:arquivo, arte: arte.arte, molde: molde, client: molde.client, peca: lingua, tamanho: cortes.second.tamanhos.first)
    create(:item_pedido, pedido: pedido, arquivo: arte, materia_prima: material).tap do |i|
      i.compor_pecas!(MoldeComposicaoService.call(arte))
      i.grades.create!(tamanho_nome: "30", quantidade: 5)
    end
  end

  def etapa(chave) = EtapasProducao.etapa("calcado", chave)

  it "keys the Impressão lines by item, part, size, file and side, pointing at their Corte line" do
    linhas = described_class.call(pedido, etapa("impressao"))
    lateral_30 = linhas.find { |l| l.peca == lateral }
    expect(lateral_30.chave).to eq([ item.uuid, lateral.uuid, lateral_30.tamanho.uuid, lateral_30.arquivo.uuid, nil ].join("/"))
    expect([ lateral_30.referencia, lateral_30.pecas, lateral_30.corte_chave ]).to eq([ item.uuid, 10, [ lateral.uuid, lateral_30.tamanho.uuid, material.uuid ].join("/") ])
  end

  it "keys the Corte lines by part, size and material, expecting the fit's metragem" do
    linhas = described_class.call(pedido, etapa("corte"))
    expect(linhas.map(&:chave)).to eq(linhas.map { |l| described_class.chave_do_corte(l.peca, l.tamanho, material) })
    expect(linhas.map(&:esperado)).to eq([ 0.2, 0.2 ])
  end

  it "expects pieces in a stage that counts them, and has no Corte line for a part that doesn't cut" do
    molde.molde_pecas.find_by(peca: lingua).update!(needs_cut: false)
    linhas = described_class.call(pedido, etapa("estamparia"))
    expect(linhas.map { |l| [ l.peca.nome, l.esperado, l.corte_chave.present? ] }).to eq([ [ "Lateral", 10, true ], [ "Língua", 10, false ] ])
  end

  # Etapa 2.7c (decided 19/10/2026): a line per item (arte × fabric), its
  # meters expected on the paper and on the fabric alike.
  it "keys a tecido pedido's lines by item and file, expecting the item's meters" do
    tecido = pedido_tecido_confirmado
    create(:item_pedido, pedido: tecido, arquivo: tecido.itens_pedido.first.arquivo, materia_prima: nil, metros: 2) # a draft's pendência
    itens = tecido.itens_pedido.order(:id).first(2)
    linhas = described_class.call(tecido, EtapasProducao.etapa("tecido", "calandra"))
    expect(linhas.map { |l| [ l.chave, l.referencia, l.esperado, l.materia_prima.present? ] }).to eq(itens.map { |i| [ "#{i.uuid}/#{i.arquivo.uuid}", i.uuid, i.metros.to_f, true ] })
  end
end
