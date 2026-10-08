require "rails_helper"

# Etapa 2.2 (3/3, decided 07/10/2026): rascunho → confirmado → em_producao
# (on the first baixa) → entregue; undoing a baixa until the delivery.
RSpec.describe "The pedido's cycle" do
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:molde) { create(:molde, partes: [ lateral ]) }
  let(:pedido) { create(:pedido, status: "confirmado") }
  let(:usuario) { create(:user) }

  before do
    corte = create(:arquivo, :corte, organized: true, peca: lateral, client: molde.client, modelo: molde.modelo, giro: "180").tap do |c|
      c.moldes << molde
      create(:tamanho, arquivo: c, nome: "29-30", numeros: %w[29 30], position: 1)
    end
    arte = create(:arquivo, molde: molde, client: molde.client, peca: lateral, tamanho: corte.tamanhos.first)
    create(:item_pedido, pedido: pedido, arquivo: arte).tap do |i|
      i.compor_pecas!(MoldeComposicaoService.call(arte))
      i.grades.create!(tamanho_nome: "30", quantidade: 5)
    end
  end

  def baixa(etapa, medida = "10")
    RegistrarBaixaService.call(pedido, etapa: etapa, nivel: "pedido", medida: medida, user: usuario).baixa
  end

  describe "em produção" do
    it "starts on the first baixa, and goes back to confirmed when its last baixa is undone" do
      primeira = baixa("impressao")
      expect(pedido.reload.status).to eq("em_producao")
      expect(DesfazerBaixaService.call(primeira, user: usuario)).to be_nil
      expect([ pedido.reload.status, primeira.reload.desfeita_por ]).to eq([ "confirmado", usuario ])
    end
  end

  describe DesfazerBaixaService do
    it "reopens the baixa's lines, kept in the history" do
      feita = baixa("corte")
      DesfazerBaixaService.call(feita, user: usuario)
      expect(RegistrarBaixaService.situacao(pedido, "corte").values.map(&:estado)).to eq([ :aberta ])
      expect(pedido.baixas_producao.da_etapa("corte").count).to eq(1)
    end

    # The Estamparia waited for this Corte: undoing it first would leave a
    # stamped line whose pieces were never cut.
    it "refuses to undo a stage another one already used, naming it" do
      baixa("impressao")
      corte = baixa("corte")
      baixa("estamparia")
      expect(DesfazerBaixaService.call(corte, user: usuario)).to eq("Undo Estamparia's baixa of these lines first: it waited for this one.")
      expect(corte.reload.desfeita_em).to be_nil
    end

    it "refuses once the pedido is delivered, and an undone baixa" do
      feita = baixa("impressao")
      EntregarPedidoService.call(pedido, confirmar: true, user: usuario)
      expect(DesfazerBaixaService.call(feita, user: usuario)).to eq("The pedido was delivered: its baixas no longer change.")
    end
  end

  describe EntregarPedidoService do
    it "warns about the open stages and delivers only once confirmed" do
      baixa("impressao")
      aviso = EntregarPedidoService.call(pedido, user: usuario)
      expect([ aviso.estado, aviso.mensagem ]).to eq([ :aviso, "Ainda faltam: Corte 1 linha, Estamparia 1 linha, Conferência 1 linha. Entregar assim mesmo?" ])
      expect(pedido.reload.status).to eq("em_producao")
      expect(EntregarPedidoService.call(pedido, confirmar: true, user: usuario).estado).to eq(:ok)
      expect(pedido.reload.attributes.values_at("status", "entregue_por_id")).to eq([ "entregue", usuario.id ])
      expect(pedido.entregue_em).to be_present
    end

    it "delivers without asking when every stage is done, and refuses a draft" do
      %w[impressao corte estamparia conferencia].each { |etapa| baixa(etapa) }
      expect(EntregarPedidoService.call(pedido, user: usuario).estado).to eq(:ok)
      rascunho = create(:pedido)
      expect(EntregarPedidoService.call(rascunho, user: usuario).mensagem).to start_with("This pedido is rascunho")
    end

    it "takes no more baixas once delivered" do
      EntregarPedidoService.call(pedido, confirmar: true, user: usuario)
      expect(RegistrarBaixaService.call(pedido, etapa: "corte", nivel: "pedido", medida: "1").mensagem).to start_with("This pedido is entregue")
    end
  end

  describe AndamentoDoPedido do
    it "counts each stage's lines done and in all" do
      baixa("impressao")
      expect(AndamentoDoPedido.call(pedido).map { |a| [ a.etapa.chave, a.feitas, a.total ] }).to eq(
        [ [ "impressao", 1, 1 ], [ "corte", 0, 1 ], [ "estamparia", 0, 1 ], [ "conferencia", 0, 1 ] ]
      )
    end
  end
end
