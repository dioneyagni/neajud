require "rails_helper"
require_relative "../support/tecidos"

# Etapa 2.3e (decided 20/10/2026): a metragem baixa adjusts the stock by the
# real minus the expected — per material (one measure each when it covers
# several), split between owners by their share — only where the pedido took
# from the stock at confirmation; undoing the baixa stops it counting.
RSpec.describe AjusteDaBaixa do
  let(:client) { create(:client) }
  let(:oxford) { criar_tecido(grupo: "Oxford") }
  let(:helanca) { criar_tecido(grupo: "Helanca") }
  let(:papel) { criar_tecido(grupo: "Papel", cor: "Branco", tipo: "papel") }
  let(:usuario) { create(:user) }
  let(:pedido) { create(:pedido, tipo: "tecido", client: client) }

  before { (Empresa.atual || create(:empresa)).update!(papel_padrao: papel) }

  def item(material, metros, dono: nil)
    pedido.itens_pedido.create!(arquivo: criar_obra_de_tecido("cor_lisa", client: client, no_catalogo: false, materia_prima: material, filename: "cor-#{SecureRandom.hex(3)}").arquivos.first,
                                materia_prima: material, metros: metros, dono_tecido: dono)
  end

  def confirmar(saida: true)
    pedido.update!(status: "confirmado")
    SaidaDoPedido.call(pedido) if saida
  end

  def baixa(etapa, medida: nil, medidas: nil)
    RegistrarBaixaService.call(pedido, etapa: etapa, nivel: "pedido", medida: medida, medidas: medidas, confirmar: true, user: usuario)
  end

  def ajustes = MovimentoEstoque.where.not(baixa_producao_id: nil).order(:id).map { |m| [ m.materia_prima, m.client, m.tipo, m.quantidade.to_f ] }

  context "a tecido pedido of 4 m of Oxford and 6 m of Helanca, both the client's" do
    before do
      item(oxford, 4)
      item(helanca, 6)
      confirmar
    end

    it "takes the paper used past the expected, and gives back what was left" do
      mais = baixa("impressao", medida: "10,5").baixa
      expect(ajustes).to eq([ [ papel, nil, "saida", 0.5 ] ])
      expect(mais.ajustes_estoque.first.pedido).to eq(pedido)
      DesfazerBaixaService.call(mais, user: usuario)
      baixa("impressao", medida: "9,5")
      expect(ajustes.last).to eq([ papel, nil, "entrada", 0.5 ])
    end

    it "asks each fabric's measure on the Calandra and adjusts each by its own" do
      baixa("impressao", medida: "10")
      expect(ajustes).to eq([])
      sem = baixa("calandra", medida: "10", medidas: { oxford.uuid => "4,4" })
      expect([ sem.estado, sem.mensagem ]).to eq([ :erro, "Missing the measure of #{helanca.nome_completo}: this baixa covers several materials, one measure (meters) each." ])
      feita = baixa("calandra", medidas: { oxford.uuid => "4,4", helanca.uuid => "5,7" }).baixa
      expect([ feita.medida.to_f, feita.medidas ]).to eq([ 10.1, { oxford.uuid => "4.4", helanca.uuid => "5.7" } ])
      expect(ajustes).to eq([ [ oxford, client, "saida", 0.4 ], [ helanca, client, "entrada", 0.3 ] ])
    end

    it "warns naming the fabric outside the dono's band" do
      baixa("impressao", medida: "10")
      aviso = RegistrarBaixaService.call(pedido, etapa: "calandra", nivel: "pedido", medida: nil, medidas: { oxford.uuid => "8", helanca.uuid => "6" })
      expect([ aviso.estado, aviso.mensagem ]).to eq([ :aviso, "#{oxford.nome_completo}: esperado ~4 m, você informou 8 m. Confira e corrija, ou confirme assim mesmo." ])
    end

    it "stops counting an undone baixa's adjustment" do
      feita = baixa("impressao", medida: "12").baixa
      expect(MovimentoEstoque.que_contam.where(materia_prima: papel).sum(:quantidade).to_f).to eq(12.0)
      DesfazerBaixaService.call(feita, user: usuario)
      expect(MovimentoEstoque.que_contam.where(materia_prima: papel).sum(:quantidade).to_f).to eq(10.0)
      expect(feita.ajustes_estoque.first.motivo_de_nao_contar).to eq("baixa desfeita")
    end
  end

  it "splits one fabric's difference between its owners by their share" do
    item(oxford, 4)
    item(oxford, 6, dono: "empresa")
    confirmar
    baixa("impressao", medida: "10")
    baixa("calandra", medida: "11")
    expect(ajustes).to eq([ [ oxford, client, "saida", 0.4 ], [ oxford, nil, "saida", 0.6 ] ])
  end

  # Decided 20/10/2026: a pedido confirmed before Etapa 2.3d2 took nothing;
  # an adjustment alone would leave the balance wrong.
  it "adjusts nothing a pedido didn't take at confirmation" do
    item(oxford, 4)
    confirmar(saida: false)
    expect(baixa("impressao", medida: "5").estado).to eq(:ok)
    expect(ajustes).to eq([])
  end
end
