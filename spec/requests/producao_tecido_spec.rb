require "rails_helper"
require_relative "../support/producao_tecido"
require_relative "../support/fake_compactacao_de_arquivo"

# Etapa 2.7c (decided 19/10/2026): a tecido pedido's Impressão (the paper)
# and Calandra (onto the fabric, after the line's paper) on one page, a line
# per item in meters, and each item's file for the RIP — compacted at
# upload, the meters and the width in its name — alone or zipped.
RSpec.describe "A tecido pedido's production", type: :request do
  let(:pedido) { pedido_tecido_confirmado }
  let(:itens) { pedido.itens_pedido.order(:id).to_a }
  let(:linhas) { LinhasDeProducao.call(pedido, EtapasProducao.etapa("tecido", "impressao")) }
  let(:nome_da_corrida) { "#{titulo_do_item(itens.first)}_12,5m_1400mm.tif" }

  before do
    CompactarArquivoTecidoJob.compactador = FakeCompactacaoDeArquivo.new
    gravar_original(itens.first.arquivo, Rails.root.join("spec/fixtures/files/01.tif"))
    gravar_original(itens.last.arquivo, Rails.root.join("spec/fixtures/files/02.tif"))
  end

  after { CompactarArquivoTecidoJob.compactador = CompactacaoDeArquivo.new }

  def baixa(etapa, **params)
    post pedido_baixas_path(pedido), params: { etapa: etapa, **params }, as: :json
    response.parsed_body
  end

  def nomes_do_zip
    Zip::File.open_buffer(StringIO.new(response.body)).entries.map(&:name)
  end

  it "links the panel and the calçado's pages to its Impressão and Calandra" do
    get resumo_pedido_path(pedido)
    expect(Nokogiri::HTML(response.body).css(".pedido-ir-producao a").map { |a| a["href"] }).to eq(%w[impressao calandra].map { |e| producao_tecido_pedido_path(pedido, etapa: e) })
    get etapa_pedido_path(pedido, etapa: "estamparia")
    expect(response).to redirect_to(producao_tecido_pedido_path(pedido, etapa: "impressao"))
    get baixar_impressao_pedido_path(pedido)
    expect(response).to redirect_to(tecido_arquivos_pedido_path(pedido))
    get producao_tecido_pedido_path(pedido, etapa: "corte")
    expect(response).to have_http_status(:not_found)
  end

  it "shows each item's fabric, width, meters and file; opening it compacts the missing copies" do
    ActiveJob::Base.queue_adapter = :test
    get producao_tecido_pedido_path(pedido, etapa: "impressao")
    html = Nokogiri::HTML(response.body)
    expect(html.css(".producao-tecido-linha").map { |tr| tr.css("td[data-rotulo]").first(3).map { |td| td.text.squish } }).to eq([
      [ itens.first.materia_prima.nome_completo, "1,4 m", "12,5 m" ], [ itens.first.materia_prima.nome_completo, "1,5 m", "3 m" ]
    ])
    expect(html.at_css("[data-producao-tecido='metros']").text).to eq("15,5 m")
    expect(html.css(".producao-tecido-linha .producao-preparando").map { |s| s["title"] }).to eq([ nome_da_corrida, "02_3m_1500mm.tif" ])
    expect(html.at_css("[data-controller='processamento']")["data-processamento-url-value"]).to eq(tecido_compactados_pedido_path(pedido))
    expect(html.css(".producao-tecido-linha .baixa-abrir").size).to eq(2)
    expect(CompactarArquivoTecidoJob).to have_been_enqueued.exactly(2).times
  ensure
    ActiveJob::Base.queue_adapter = :inline
  end

  it "takes the Calandra's baixa only after the line's paper, in meters against the item's" do
    calandra = linhas.first.chave
    expect(baixa("calandra", nivel: "linha", alvo: calandra, medida: "12,5")["error"]).to eq("Waiting for Impressão: this line can't have its Calandra baixa yet.")
    expect(baixa("impressao", nivel: "linha", alvo: calandra, medida: "9")["aviso"]).to include("Esperado ~12,50 m, você informou 9 m.")
    expect(baixa("impressao", nivel: "linha", alvo: calandra, medida: "12.6")["ok"]).to be(true)
    expect(baixa("calandra", nivel: "pedido", medida: "12,5")["ok"]).to be(true)
    expect(pedido.reload.baixas_producao.vigentes.map { |b| [ b.etapa, b.linhas ] }).to eq([ [ "impressao", [ calandra ] ], [ "calandra", [ calandra ] ] ])
    expect(pedido.status).to eq("em_producao")
    get producao_tecido_pedido_path(pedido, etapa: "calandra")
    situacoes = Nokogiri::HTML(response.body).css(".producao-tecido-linha .etapa-situacao")
    expect([ situacoes.first.at_css(".baixa-feita").text.squish, situacoes.last.text.squish ]).to match([ start_with("✓ 12,50 m"), "aguardando Impressão" ])
  end

  it "downloads an item's file compacted, under its meters and width, and zips them all" do
    get tecido_arquivo_pedido_path(pedido, linha: linhas.first.chave)
    expect(response).to redirect_to(producao_tecido_pedido_path(pedido, etapa: "impressao"))
    expect(flash[:alert]).to eq("O arquivo compactado ainda está sendo preparado (#{nome_da_corrida}).")
    get tecido_compactados_pedido_path(pedido)
    expect(response.parsed_body).to eq("final" => false)

    get producao_tecido_pedido_path(pedido, etapa: "impressao") # compacts them (inline in specs)
    get tecido_compactados_pedido_path(pedido)
    expect(response.parsed_body).to eq("final" => true)
    get tecido_arquivo_pedido_path(pedido, linha: linhas.first.chave)
    expect(response.headers["Content-Disposition"]).to include(ERB::Util.url_encode(nome_da_corrida))
    expect(response.body.b).to eq(File.binread(Rails.root.join("spec/fixtures/files/01.tif")))
    get tecido_arquivos_pedido_path(pedido)
    expect(nomes_do_zip).to eq([ nome_da_corrida, "02_3m_1500mm.tif" ])
  end

  # A draft's items still change (meters, fabric, width): nothing goes to the RIP yet.
  it "offers no file for the RIP before the pedido is confirmed" do
    pedido.update!(status: "enviado")
    get producao_tecido_pedido_path(pedido, etapa: "impressao")
    expect(response.body).not_to include("producao-tecido-arquivo", "impressao-zip", "compactando")
    get tecido_arquivos_pedido_path(pedido)
    expect(flash[:alert]).to eq("This pedido is enviado: its files go to the RIP once it is confirmed.")
  end

  it "answers 404 to a line that isn't in the pedido, and opens by uuid only" do
    get tecido_arquivo_pedido_path(pedido, linha: "#{SecureRandom.uuid}/#{SecureRandom.uuid}")
    expect(response).to have_http_status(:not_found)
    get producao_tecido_pedido_path(pedido.id, etapa: "impressao")
    expect(response).to have_http_status(:not_found)
    get producao_tecido_pedido_path(create(:pedido, tipo: "dtf"), etapa: "impressao")
    expect(response).to have_http_status(:not_found)
  end

  it "the files for the RIP need baixar_producao; the page only pedidos: ver" do
    entrar_com_funcao(niveis: { "pedidos" => 3 })
    [ tecido_arquivo_pedido_path(pedido, linha: linhas.first.chave), tecido_arquivos_pedido_path(pedido), tecido_compactados_pedido_path(pedido) ].each do |caminho|
      get caminho
      expect(response).to have_http_status(:forbidden)
    end
    get producao_tecido_pedido_path(pedido, etapa: "calandra")
    expect([ response.status, response.body.include?("producao-tecido-arquivo") ]).to eq([ 200, false ])
  end

  it "a cliente final follows his pedido's lines, without the files or the baixas" do
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user), client: pedido.client, funcao: funcao).user)
    get producao_tecido_pedido_path(pedido, etapa: "impressao")
    html = Nokogiri::HTML(response.body)
    expect([ html.css(".producao-tecido-linha").size, html.css(".baixa-abrir, .producao-tecido-arquivo").size ]).to eq([ 2, 0 ])
  end
end
