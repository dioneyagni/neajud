require "rails_helper"

# Etapa 0.3: uploads enqueue ArquivoProcessingJob instead of running it in
# the request, and the UI shows the queued state.
RSpec.describe "Queued processing", type: :request do
  let(:tif) { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/02-no_spot.tif"), "image/tiff") }

  # RSpec's env runs jobs inline; these examples need to see them enqueued.
  around do |example|
    previous = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous
    Arquivo.find_each { |a| FileUtils.rm_rf(File.join(ArquivoVersion::STORAGE_BASE, a.uuid)) }
  end

  it "POST /arquivos enqueues processing and responds with the version still pending" do
    expect { post arquivos_path, params: { arquivo: { original_file: tif } } }
      .to have_enqueued_job(ArquivoProcessingJob)
    expect(response).to redirect_to(arquivos_path)
    expect(Arquivo.last.status).to eq("pending")
  end

  it "POST upload_version enqueues processing of the new version" do
    arquivo = create(:arquivo)
    create(:arquivo_version, arquivo: arquivo, version_number: 1, approved: true)
    expect { post upload_version_arquivo_path(arquivo), params: { original_file: tif } }
      .to have_enqueued_job(ArquivoProcessingJob)
    expect(arquivo.reload.status).to eq("pending")
  end

  it "shows 'Na fila' on the gallery card with data-status, and a banner on the arquivo page" do
    arquivo = create(:arquivo, filename: "na-fila")
    create(:arquivo_version, arquivo: arquivo, status: "pending").tap { |v| arquivo.update!(approved_version: v) }

    get arquivos_path
    card = Nokogiri::HTML(response.body).at_css("##{ActionView::RecordIdentifier.dom_id(arquivo)}")
    expect([ card["data-status"], card["data-filename"] ]).to eq([ "pending", "na-fila" ])
    expect(card.at_css(".stamp-card-badge").text).to eq("Na fila")

    get arquivo_path(arquivo)
    html = Nokogiri::HTML(response.body)
    expect(html.at_css(".processamento-status").text).to include("Na fila")
    expect(html.at_css("turbo-cable-stream-source")).to be_present
  end

  describe "polling safety net for a missed broadcast" do
    def arquivo_with(status, **attrs)
      create(:arquivo, **attrs).tap do |a|
        create(:arquivo_version, arquivo: a, status: status).tap { |v| a.update!(approved_version: v) }
      end
    end

    it "GET processamento.json reports the status and whether it is final" do
      queued = arquivo_with("processing")
      get processamento_arquivo_path(queued, format: :json)
      expect(response.parsed_body).to eq("status" => "processing", "final" => false)
      done = arquivo_with("processed")
      get processamento_arquivo_path(done, format: :json)
      expect(response.parsed_body).to eq("status" => "processed", "final" => true)
    end

    it "GET processamento as turbo-stream replaces the gallery card" do
      done = arquivo_with("processed")
      get processamento_arquivo_path(done), headers: { "Accept" => "text/vnd.turbo-stream.html" }
      stream = Nokogiri::HTML(response.body).at_css("turbo-stream")
      expect([ stream["action"], stream["target"] ]).to eq([ "replace", "arquivo_#{done.id}" ])
    end

    it "only queued cards poll (a processed card stops)" do
      queued = arquivo_with("pending", filename: "fila")
      done = arquivo_with("processed", filename: "pronto")
      get arquivos_path
      html = Nokogiri::HTML(response.body)
      queued_card = html.at_css("#arquivo_#{queued.id}")
      expect([ queued_card["data-controller"], queued_card["data-processamento-mode-value"] ]).to eq([ "processamento", "card" ])
      expect(queued_card["data-processamento-url-value"]).to eq(processamento_arquivo_path(queued))
      expect(html.at_css("#arquivo_#{done.id}")["data-controller"]).to be_nil
    end

    it "the arquivo page banner and a pedido piece with a queued arte poll for the end" do
      queued = arquivo_with("processing")
      get arquivo_path(queued)
      expect(Nokogiri::HTML(response.body).at_css(".processamento-status")["data-controller"]).to eq("processamento")

      pedido = create(:pedido)
      item = create(:item_pedido, pedido: pedido)
      create(:item_pedido_peca, item_pedido: item, arquivo: queued)
      get pedido_path(pedido)
      thumb = Nokogiri::HTML(response.body).at_css(".pedido-peca [data-controller='processamento']")
      expect(thumb.text).to include("processando")
      expect(thumb["data-processamento-url-value"]).to eq(processamento_arquivo_path(queued, format: :json))
    end
  end
end
