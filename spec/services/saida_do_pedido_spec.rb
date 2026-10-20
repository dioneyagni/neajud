require "rails_helper"
require_relative "../support/producao_tecido"

# Etapa 2.3d2 (decided 19/10/2026): confirming takes the expected meters
# from the stock, one out per material × owner, pointing at the pedido; what
# has no material or metragem is warned about, never blocks.
RSpec.describe SaidaDoPedido do
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:lingua) { create(:peca, nome: "Língua") }
  let(:molde) { create(:molde, partes: [ lateral, lingua ]) }
  let(:tactel) { criar_tecido(largura: "1.40 m", grupo: "Tactel") }
  let(:papel) { criar_tecido(largura: "1.60 m", grupo: "Papel", cor: "Branco", tipo: "papel") }
  let(:pedido) { create(:pedido, status: "confirmado", client: molde.client) }
  let(:artes) do
    cortes = [ lateral, lingua ].map do |peca|
      create(:arquivo, :corte, organized: true, peca: peca, client: molde.client, modelo: molde.modelo, giro: "180").tap do |c|
        c.moldes << molde
        create(:tamanho, arquivo: c, nome: "29-30", numeros: %w[29 30], position: 1, metros_por_peca: { "1400" => 0.02 })
      end
    end
    arte = create(:arquivo, molde: molde, client: molde.client, peca: lateral, tamanho: cortes.first.tamanhos.first)
    [ arte, create(:arquivo, arte: arte.arte, molde: molde, client: molde.client, peca: lingua, tamanho: cortes.second.tamanhos.first) ]
  end

  before { (Empresa.atual || create(:empresa)).update!(papel_padrao: papel) }

  # 5 pairs × 2 parts × 1 piece: 10 pieces of each part, 0,02 m each on the fabric.
  def item_calcado(em: pedido, dono: nil, material: tactel)
    create(:item_pedido, pedido: em, arquivo: artes.first, materia_prima: material, dono_tecido: dono).tap do |i|
      i.compor_pecas!(MoldeComposicaoService.call(artes.first))
      i.grades.create!(tamanho_nome: "30", quantidade: 5)
    end
  end

  # 189 × 59 px at 300 dpi: 16 × 5 mm, 100 across 1,60 m of paper — 0,00005 m a piece.
  def com_medida(arquivos)
    arquivos.each do |arquivo|
      versao = arquivo.approved_version || create(:arquivo_version, arquivo: arquivo, approved: true, status: "processed").tap { |v| arquivo.update!(approved_version: v) }
      ArquivoImageMetadata.create!(arquivo_version: versao, width_px: 189, height_px: 59, dpi: 300)
    end
  end

  def saidas(em = pedido)
    em.movimentos_estoque.order(:id).map { |m| [ m.materia_prima.grupo_material.nome, m.client&.name, m.tipo, m.quantidade.to_f ] }
  end

  it "takes a calçado's fabric from its owner and the paper from the empresa, warning about a file without measure" do
    com_medida([ artes.first ])
    item_calcado
    expect(described_class.call(pedido)).to eq([ "Impressão: #{artes.second.filename} has no metragem (its size or DPI)" ])
    expect(saidas).to contain_exactly([ "Papel", nil, "saida", 0.0005 ], [ "Tactel", molde.client.name, "saida", 0.4 ])
  end

  it "splits the fabric by each item's owner — items of different moldes may differ" do
    com_medida(artes)
    item_calcado(dono: "empresa")
    item_calcado(dono: "cliente")
    described_class.call(pedido)
    expect(saidas).to contain_exactly([ "Papel", nil, "saida", 0.002 ], [ "Tactel", nil, "saida", 0.4 ], [ "Tactel", molde.client.name, "saida", 0.4 ])
  end

  it "warns about a line without fabric and a missing default paper, and takes once only" do
    Empresa.atual.update!(papel_padrao: nil)
    item_calcado(material: nil)
    expect(described_class.call(pedido)).to eq([ "Impressão: no paper chosen and no default one in Parâmetros", "Corte: Lateral 29-30 has no fabric chosen", "Corte: Língua 29-30 has no fabric chosen" ])
    expect(saidas).to be_empty
    pedido.movimentos_estoque.create!(materia_prima: tactel, da_empresa: true, tipo: "saida", quantidade: 1)
    expect { described_class.call(pedido) }.not_to change(MovimentoEstoque, :count)
  end

  it "takes a tecido's item meters of its fabric (the item's owner) and of the paper" do
    tecido = pedido_tecido_confirmado
    tecido.itens_pedido.first.update!(dono_tecido: "empresa")
    tecido.itens_pedido.second.update!(dono_tecido: "cliente")
    expect(described_class.call(tecido)).to eq([])
    expect(saidas(tecido)).to contain_exactly([ "Papel", nil, "saida", 15.5 ], [ "Oxford", nil, "saida", 12.5 ], [ "Oxford", tecido.client.name, "saida", 3.0 ])
  end

  it "takes a DTF's film meters of the fit written at confirmation" do
    dtf = pedido_dtf_confirmado
    filme = criar_tecido(largura: "60 cm", grupo: "Filme", tipo: "filme_dtf")
    dtf.update_columns(material_impressao_id: filme.id)
    described_class.call(dtf)
    expect(saidas(dtf)).to eq([ [ "Filme", nil, "saida", EncaixeDoPedidoDtf.call(dtf).sum(&:metros).round(4) ] ])
  end

  # Etapa 2.2 (4/4): a released reposição redoes pieces; their fabric comes
  # from the owner of the item they came from, the paper only when reprinted.
  it "takes a released reposição's pieces from the original item's owner" do
    item = item_calcado(dono: "empresa")
    reposicao = Pedido.create!(status: "rascunho", client: pedido.client, tipo: "calcado", reposicao_de: pedido)
    reposicao.itens_reposicao.create!(item_origem: item, arquivo: artes.first, peca: lateral, tamanho: artes.first.tamanho, materia_prima: tactel,
                                      pecas: 3, corta: true, refazer_corte: true, refazer_impressao: false)
    LiberarReposicaoService.call(pedido)
    expect(saidas(reposicao)).to eq([ [ "Tactel", nil, "saida", 0.06 ] ])
  end
end
