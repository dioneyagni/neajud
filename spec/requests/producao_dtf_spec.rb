require "rails_helper"
require_relative "../support/producao_dtf"
require_relative "../support/fake_giro_de_arquivo"

# Etapa 2.6b2 (decided 15/10/2026): a DTF pedido's Impressão and Corte on one
# page, a line per etiqueta × size, and each line's file for the RIP —
# turned when the fit turned it, the units in its name — alone or zipped.
RSpec.describe "A DTF pedido's production", type: :request do
  let(:pedido) { pedido_dtf_confirmado }
  let(:titulo_p) { titulo_do_tamanho(pedido, "P") }
  let(:titulo_g) { titulo_do_tamanho(pedido, "G") }
  let(:linhas) { LinhasDeProducao.call(pedido, EtapasProducao.etapa("dtf", "impressao")) }

  before do
    GirarArquivoDtfJob.girador = FakeGiroDeArquivo.new
    gravar_original(arquivo_do_tamanho(pedido, "P"), Rails.root.join("spec/fixtures/files/01.tif"))
    gravar_original(arquivo_do_tamanho(pedido, "G"), Rails.root.join("spec/fixtures/files/02.tif"))
  end

  after { GirarArquivoDtfJob.girador = GiroDeArquivo.new }

  def nomes_do_zip
    Zip::File.open_buffer(StringIO.new(response.body)).entries.map(&:name)
  end

  it "links the panel and the old pages to its stages; on the roll there is no Corte" do
    get resumo_pedido_path(pedido)
    links = Nokogiri::HTML(response.body).css(".pedido-ir-producao a").map { |a| a["href"] }
    expect(links).to eq(%w[impressao corte].map { |e| producao_dtf_pedido_path(pedido, etapa: e) })
    get corte_pedido_path(pedido)
    expect(response).to redirect_to(producao_dtf_pedido_path(pedido, etapa: "corte"))

    rolo = pedido_dtf_confirmado(entrega: "rolo")
    get producao_dtf_pedido_path(rolo, etapa: "corte")
    expect(response).to have_http_status(:not_found)
  end

  it "shows each size's fit, its file for the RIP and its baixa; opening it turns the missing copies" do
    ActiveJob::Base.queue_adapter = :test
    get producao_dtf_pedido_path(pedido, etapa: "impressao")
    html = Nokogiri::HTML(response.body)
    expect(html.css(".producao-dtf-linha").map { |tr| [ tr["data-tamanho"], tr.at_css("[data-impressas]").text ] }).to eq([ %w[P 44], %w[G 18] ])
    expect(html.at_css(".producao-dtf-linha[data-tamanho='P'] .producao-dtf-arquivo")["data-nome"]).to eq("#{titulo_p}_P_44un.tif")
    expect(html.at_css(".producao-dtf-linha[data-tamanho='G'] .producao-dtf-preparando").text).to eq("preparando…")
    expect(html.at_css("[data-controller='processamento']")["data-processamento-url-value"]).to eq(dtf_girados_pedido_path(pedido))
    expect(html.css(".producao-dtf-linha .baixa-abrir").size).to eq(2)
    expect(html.css(".producao-dtf-linha .pedido-dtf-girada").map { |s| s.ancestors("tr").first["data-tamanho"] }).to eq(%w[G])
    expect(GirarArquivoDtfJob).to have_been_enqueued.with(arquivo_do_tamanho(pedido, "G").approved_version.id)
  ensure
    ActiveJob::Base.queue_adapter = :inline
  end

  it "downloads a line's file under the units to print, the turned one once ready" do
    get dtf_arquivo_pedido_path(pedido, linha: linhas.first.chave)
    expect(response.headers["Content-Disposition"]).to include("#{titulo_p}_P_44un.tif")
    expect(response.body.b).to eq(File.binread(Rails.root.join("spec/fixtures/files/01.tif")))

    get dtf_girados_pedido_path(pedido)
    expect(response.parsed_body).to eq("final" => false)
    get dtf_arquivo_pedido_path(pedido, linha: linhas.last.chave)
    expect(response).to redirect_to(producao_dtf_pedido_path(pedido, etapa: "impressao"))

    get producao_dtf_pedido_path(pedido, etapa: "impressao") # turns it (inline in specs)
    get dtf_girados_pedido_path(pedido)
    expect(response.parsed_body).to eq("final" => true)
    get dtf_arquivo_pedido_path(pedido, linha: linhas.last.chave)
    expect(response.headers["Content-Disposition"]).to include("#{titulo_g}_G_18un_girada.tif")
  end

  # A draft's fit still changes (more units, extra rows): nothing goes to the RIP yet.
  it "offers no file for the RIP before the pedido is confirmed" do
    pedido.update!(status: "rascunho")
    get producao_dtf_pedido_path(pedido, etapa: "impressao")
    expect(response.body).not_to include("producao-dtf-arquivo", "impressao-zip", "preparando")
    get dtf_arquivo_pedido_path(pedido, linha: linhas.first.chave)
    expect(response).to redirect_to(producao_dtf_pedido_path(pedido, etapa: "impressao"))
    expect(flash[:alert]).to eq("This pedido is rascunho: its files go to the RIP once it is confirmed.")
  end

  it "answers 404 to a line that isn't in the pedido" do
    get dtf_arquivo_pedido_path(pedido, linha: "#{SecureRandom.uuid}/P/#{SecureRandom.uuid}")
    expect(response).to have_http_status(:not_found)
  end

  it "zips every file, also from the old zip link, once the turned ones are ready" do
    get dtf_arquivos_pedido_path(pedido)
    expect(response).to redirect_to(producao_dtf_pedido_path(pedido, etapa: "impressao"))
    expect(flash[:alert]).to eq("O arquivo girado ainda está sendo preparado.")

    get producao_dtf_pedido_path(pedido, etapa: "impressao")
    get baixar_impressao_pedido_path(pedido)
    follow_redirect!
    expect(response.headers["Content-Disposition"]).to include("Impressao #{pedido.uuid.first(8)}.zip")
    expect(nomes_do_zip).to eq([ "#{titulo_p}_P_44un.tif", "#{titulo_g}_G_18un_girada.tif" ])
  end

  it "confirming a DTF pedido turns its files for the RIP" do
    Empresa.atual.update!(preco_metro_dtf: 120, preco_corte_dtf: 0.05)
    rascunho = pedido.tap { |p| p.update!(status: "rascunho") }
    post confirmar_pedido_path(rascunho)
    expect(rascunho.reload.status).to eq("confirmado")
    expect(GirarArquivoDtfJob.girador.girados).to eq([ arquivo_do_tamanho(pedido, "G").approved_version.original_path ])
  end

  it "the files for the RIP need baixar_producao; the page only pedidos: ver" do
    entrar_com_funcao(niveis: { "pedidos" => 3 })
    [ dtf_arquivo_pedido_path(pedido, linha: linhas.first.chave), dtf_arquivos_pedido_path(pedido), dtf_girados_pedido_path(pedido) ].each do |caminho|
      get caminho
      expect(response).to have_http_status(:forbidden)
    end
    get producao_dtf_pedido_path(pedido, etapa: "impressao")
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("producao-dtf-arquivo")
    entrar_com_funcao(niveis: { "pedidos" => 0 })
    get producao_dtf_pedido_path(pedido, etapa: "impressao")
    expect(response).to have_http_status(:forbidden)
  end

  # The turn is the team's (Etapa 2.6b1, D5): the client never sees the fit's choices.
  it "a cliente final sees his pedido's lines without the turn" do
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user), client: pedido.client, funcao: funcao).user)
    get producao_dtf_pedido_path(pedido, etapa: "impressao")
    html = Nokogiri::HTML(response.body)
    expect(html.css(".producao-dtf-linha").size).to eq(2)
    expect(html.css(".pedido-dtf-girada")).to be_empty
  end

  it "opens by uuid only: a calçado pedido or an integer id is a 404" do
    get producao_dtf_pedido_path(pedido.id, etapa: "impressao")
    expect(response).to have_http_status(:not_found)
    get producao_dtf_pedido_path(create(:pedido), etapa: "impressao")
    expect(response).to have_http_status(:not_found)
  end
end
