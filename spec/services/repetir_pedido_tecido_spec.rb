require "rails_helper"
require_relative "../support/tecidos"

# Decided 20/10/2026: repeating a tecido pedido makes a new draft of the same
# client — the same artes, fabrics, widths, owner and paper, the meters of
# this time (0 leaves an item out) and the prices it was charged; one below
# today's is warned (PrecosDoItemTecido#precos_abaixo_do_valor).
RSpec.describe RepetirPedidoTecido do
  let(:client) { create(:client) }
  let(:oxford) { criar_tecido(grupo: "Oxford").tap { |t| t.update!(preco_metro: 20) } }
  let(:helanca) { criar_tecido(grupo: "Helanca") }
  let(:papel) { criar_tecido(grupo: "Papel", cor: "Branco", tipo: "papel") }
  let(:origem) do
    create(:pedido, tipo: "tecido", client: client, dono_tecido: "empresa", material_impressao: papel).tap do |p|
      [ [ oxford, 12, 1500 ], [ helanca, 8, nil ] ].each do |material, metros, largura|
        arquivo = criar_obra_de_tecido("cor_lisa", client: client, no_catalogo: false, materia_prima: material, filename: "cor-#{material.id}").arquivos.first
        p.itens_pedido.create!(arquivo: arquivo, materia_prima: material, metros: metros, largura_mm: largura, preco_impressao_metro: 14)
      end
    end
  end

  before do
    (Empresa.atual || create(:empresa)).update!(preco_impressao_metro_tecido: 15)
    # As confirming does: the owner and the prices written while a draft.
    origem.gravar_dono_do_tecido!
    ValoresDoPedidoTecido.gravar!(origem)
    origem.update!(status: "entregue")
  end

  def repetir(metros = {}) = described_class.call(origem, metros: metros, pedidos: Pedido.all)

  it "makes a draft of the same client with the artes, fabrics, widths, owner, paper and the meters asked" do
    oxford_item, helanca_item = origem.itens_pedido.order(:id)
    novo = repetir(oxford_item.uuid => "24.5", helanca_item.uuid => "8").pedido
    expect(novo.attributes.values_at("status", "tipo", "client_id", "dono_tecido", "material_impressao_id")).to eq([ "rascunho", "tecido", client.id, "empresa", papel.id ])
    expect(novo.itens_pedido.order(:id).map { |i| [ i.arquivo, i.materia_prima, i.metros.to_f, i.largura_mm ] })
      .to eq([ [ oxford_item.arquivo, oxford, 24.5, 1500 ], [ helanca_item.arquivo, helanca, 8.0, nil ] ])
  end

  it "brings the prices charged, warned when below today's" do
    item = repetir.pedido.itens_pedido.find_by!(materia_prima: oxford)
    expect([ item.preco_impressao_metro.to_f, item.preco_tecido_metro.to_f ]).to eq([ 14.0, 20.0 ])
    expect(item.precos_abaixo_do_valor).to eq("Impressão" => [ 14, 15 ])
    oxford.update!(preco_metro: 22)
    expect(item.reload.precos_abaixo_do_valor.keys).to eq(%w[Impressão Tecido])
  end

  it "leaves out an item at 0 m and an arte in the trash, naming it" do
    oxford_item, helanca_item = origem.itens_pedido.order(:id)
    helanca_item.arquivo.excluir!(changed_by: "127.0.0.1")
    resultado = repetir(oxford_item.uuid => "0")
    expect(resultado.pedido.itens_pedido).to be_empty
    expect(resultado.de_fora).to eq([ helanca_item.arte.titulo ])
  end

  it "refuses a draft, a trashed pedido, every item at 0 m and invalid meters, creating nothing" do
    expect { repetir(origem.itens_pedido.to_h { |i| [ i.uuid, "0" ] }) }.to raise_error(described_class::NaoRepetivel, "Nothing to repeat: every item is at 0 m")
    expect { repetir(origem.itens_pedido.first.uuid => "1.25") }.to raise_error(ActiveRecord::RecordInvalid, /more than one decimal/)
    expect(Pedido.where(status: "rascunho")).to be_empty
    origem.update!(status: "rascunho")
    expect(described_class.erro(origem)).to eq("Only a confirmed tecido pedido is repeated (confirmado, em_producao, entregue); this one is rascunho")
    origem.update!(status: "entregue")
    origem.excluir!(changed_by: "127.0.0.1")
    expect(described_class.erro(origem)).to eq("#{origem.rotulo_lixeira} is in the trash")
  end
end
