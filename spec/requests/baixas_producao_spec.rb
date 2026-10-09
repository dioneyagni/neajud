require "rails_helper"

# Etapa 2.2 (2/3, decided 07/10/2026): the baixa from the stage pages.
RSpec.describe "Production baixas", type: :request do
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:molde) { create(:molde, partes: [ lateral ]) }
  let(:material) { MateriaPrima.create!(grupo_material: GrupoMaterial.create!(nome: "Tactel"), cor_material: CorMaterial.create!(nome: "Azul"), largura: "1.40 m", gramatura: "80g") }
  let(:pedido) { create(:pedido, status: "confirmado") }
  let!(:item) do
    corte = create(:arquivo, :corte, organized: true, peca: lateral, client: molde.client, modelo: molde.modelo, giro: "180").tap do |c|
      c.moldes << molde
      create(:tamanho, arquivo: c, nome: "29-30", numeros: %w[29 30], position: 1, metros_por_peca: { "1400" => 0.02 })
    end
    arte = create(:arquivo, molde: molde, client: molde.client, peca: lateral, tamanho: corte.tamanhos.first)
    create(:item_pedido, pedido: pedido, arquivo: arte, materia_prima: material).tap do |i|
      i.compor_pecas!(MoldeComposicaoService.call(arte))
      i.grades.create!(tamanho_nome: "30", quantidade: 5)
    end
  end

  def baixa(etapa, medida, **extra)
    post pedido_baixas_path(pedido), params: { etapa: etapa, nivel: "pedido", medida: medida, **extra }, as: :json
  end

  it "registers the whole pedido's Corte and says so on the page" do
    baixa("corte", "0,2")
    expect(response.parsed_body).to eq("ok" => true)
    expect(flash[:notice]).to eq("Baixa de Corte registrada (1 linha).")
    get corte_pedido_path(pedido)
    html = Nokogiri::HTML(response.body)
    expect(html.at_css(".etapa-andamento-texto").text).to eq("1 de 1 linha feita")
    expect(html.at_css(".etapa-situacao .baixa-feita").text.squish).to start_with("✓ 0,20 m ·")
  end

  it "answers a warning outside the band, and saves it marked once confirmed" do
    baixa("corte", "1")
    expect(response.parsed_body).to eq("ok" => false, "aviso" => "Esperado ~0,20 m, você informou 1 m. Confira e corrija, ou confirme assim mesmo.")
    baixa("corte", "1", confirmar: "1")
    expect(pedido.baixas_producao.sole.fora_da_faixa).to be true
  end

  it "refuses with the reason, and an unknown stage" do
    baixa("estamparia", "10")
    expect([ response.status, response.parsed_body["error"] ]).to eq([ 422, "Nothing open to give Estamparia's baixa (done or waiting for Impressão, Corte)." ])
    baixa("costura", "1")
    expect(response.parsed_body["error"]).to include('unknown production stage "costura"')
  end

  it "shows the stage page: the Estamparia waits for the Impressão and the Corte" do
    get etapa_pedido_path(pedido, etapa: "estamparia")
    html = Nokogiri::HTML(response.body)
    expect(html.at_css("tr.etapa-linha .baixa-aguardando").text).to eq("aguardando Impressão")
    expect(html.css(".etapas-nav a").map(&:text)).to eq(%w[Impressão Corte Estamparia Conferência])
    expect(html.at_css(".etapas-nav a[aria-current=page]").text).to eq("Estamparia")
  end

  it "offers the baixa of each line, the referência and the pedido on the Impressão page" do
    get impressao_pedido_path(pedido)
    html = Nokogiri::HTML(response.body)
    niveis = html.css("[data-controller=baixa]").map { |b| b["data-baixa-nivel-value"] }
    expect(niveis).to contain_exactly("pedido", "referencia", "linha")
    expect(html.at_css("[data-baixa-nivel-value=referencia]")["data-baixa-alvo-value"]).to eq(item.uuid)
  end

  it "offers no baixa on a draft" do
    pedido.update!(status: "rascunho")
    get impressao_pedido_path(pedido)
    expect(Nokogiri::HTML(response.body).css("[data-controller=baixa]")).to be_empty
  end

  it "links every stage from the pedido's panel" do
    get resumo_pedido_path(pedido)
    links = Nokogiri::HTML(response.body).css(".pedido-ir-producao a").map { |a| a["href"] }
    expect(links).to eq([ impressao_pedido_path(pedido), corte_pedido_path(pedido), etapa_pedido_path(pedido, etapa: "estamparia"), etapa_pedido_path(pedido, etapa: "conferencia") ])
  end

  it "answers 404 to a stage the pedido type doesn't have" do
    get etapa_pedido_path(pedido, etapa: "costura")
    expect(response).to have_http_status(:not_found)
  end

  # Etapa 2.2 (3/3): the cycle on the pages.
  describe "the pedido's cycle" do
    it "undoes a baixa from its line, going back to the page, and lists it struck through" do
      baixa("corte", "0,2")
      feita = pedido.baixas_producao.sole
      delete pedido_baixa_path(pedido, feita), headers: { "Referer" => corte_pedido_path(pedido) }
      expect([ response.location, flash[:notice] ]).to eq([ "http://www.example.com#{corte_pedido_path(pedido)}", "Baixa de Corte desfeita (1 linha em aberto de novo)." ])
      get corte_pedido_path(pedido)
      html = Nokogiri::HTML(response.body)
      expect(html.at_css(".historico-baixa--desfeita")).to be_present
      expect(html.at_css("tr.corte-linha [data-controller=baixa]")).to be_present
    end

    it "delivers from the panel, warning about what is open, then shows the delivery" do
      post entregar_pedido_path(pedido), as: :json
      expect(response.parsed_body).to eq("ok" => false, "aviso" => "Ainda faltam: Impressão 1 linha, Corte 1 linha, Estamparia 1 linha, Conferência 1 linha. Entregar assim mesmo?")
      post entregar_pedido_path(pedido), params: { confirmar: "1" }, as: :json
      expect(response.parsed_body).to eq("ok" => true)
      get resumo_pedido_path(pedido)
      html = Nokogiri::HTML(response.body)
      expect(html.at_css(".pedido-entregue").text).to start_with("Entregue em")
      expect(html.at_css("h2 .badge").text).to eq("entregue")
      expect(html.at_css(".entrega")).to be_nil
    end

    it "shows each stage's progress on the panel" do
      baixa("corte", "0,2")
      get resumo_pedido_path(pedido)
      andamento = Nokogiri::HTML(response.body).css(".pedido-andamento li").map { |li| li.text.squish }
      expect(andamento).to eq([ "Impressão 0/1", "Corte 1/1", "Estamparia 0/1", "Conferência 0/1" ])
      expect(pedido.reload.status).to eq("em_producao")
    end

    it "filters the list by status, showing the progress of a pedido in production" do
      baixa("corte", "0,2")
      rascunho = create(:pedido)
      get pedidos_path(status: "em_producao")
      html = Nokogiri::HTML(response.body)
      expect(html.text).not_to include(rascunho.uuid.first(8))
      expect(html.at_css(".pedido-andamento-compacto").text.squish).to eq("Impressão 0/1 · Corte 1/1 · Estamparia 0/1 · Conferência 0/1")
      expect(html.at_css(".pedidos-filtro a[aria-current=page]").text).to eq("Em produção")
    end
  end
end
