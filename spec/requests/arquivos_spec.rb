require "rails_helper"

RSpec.describe "Arquivos", type: :request do
  describe "GET /" do
    it "returns http success" do
      get root_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /arquivos/:id" do
    it "returns http success for existing arquivo" do
      arquivo = create(:arquivo)
      get arquivo_path(arquivo)
      expect(response).to have_http_status(:success)
    end

    it "returns 404 for nonexistent arquivo" do
      get arquivo_path("nonexistent")
      expect(response).to have_http_status(:not_found)
    end

    it "renders version upload form with Stimulus upload controller data attributes" do
      arquivo = create(:arquivo)
      get arquivo_path(arquivo)
      expect(response.body).to include('data-controller="upload"')
      expect(response.body).to include('data-upload-target="dropzone"')
      expect(response.body).to include('data-upload-target="input"')
      expect(response.body).to include('data-upload-target="fileList"')
      expect(response.body).to include('data-upload-target="submit"')
    end

    it "renders version upload drop zone drag-and-drop event handlers" do
      arquivo = create(:arquivo)
      get arquivo_path(arquivo)
      expect(response.body).to include('dragenter->upload#dragOver')
      expect(response.body).to include('dragover->upload#dragOver')
      expect(response.body).to include('dragleave->upload#dragLeave')
      expect(response.body).to include('drop->upload#drop')
      expect(response.body).to include('click->upload#click')
    end

    # Regression: 019535b only rendered Size Selection when the corte had an
    # organize_error, so selecting client + molde never showed the size.
    it "renders Size Selection with the linked tamanho dimensions for an arte with client + molde" do
      tamanho = create(:tamanho, nome: "M", width_mm: 150.0, height_mm: 250.0)
      arquivo = create(:arquivo, client: create(:client), molde: create(:molde), tamanho: tamanho)
      get arquivo_path(arquivo)
      expect(response.body).to include('id="size-selection-section"')
      expect(response.body).to include("→ M")
      expect(response.body).to include("150.0×250.0 mm")
    end

    it "keeps the Size Selection placeholder hidden for an arte without molde" do
      arquivo = create(:arquivo, client: create(:client))
      get arquivo_path(arquivo)
      expect(response.body).to match(/id="size-selection-section"[^>]*style="display:none"/m)
    end

    it "does not render Size Selection for corte arquivos" do
      arquivo = create(:arquivo, :corte)
      get arquivo_path(arquivo)
      expect(response.body).not_to include('id="size-selection-section"')
    end
  end

  describe "GET /arquivos (gallery pagination and view toggle)" do
    let!(:arquivo) { create(:arquivo) }

    it "defaults to grid view" do
      get arquivos_path
      expect(response.body).to include('view-toggle-btn--active')
      expect(response.body).to include('class="gallery"')
    end

    it "renders list view when view=list" do
      get arquivos_path(view: "list")
      expect(response.body).to include('class="list-view"')
      expect(response.body).not_to include('class="gallery"')
    end

    it "renders grid view when view=grid" do
      get arquivos_path(view: "grid")
      expect(response.body).to include('class="gallery"')
      expect(response.body).not_to include('class="list-view"')
    end

    it "falls back to grid for invalid view param" do
      get arquivos_path(view: "invalid")
      expect(response.body).to include('class="gallery"')
    end

    it "marks the active toggle button" do
      get arquivos_path(view: "list")
      expect(response.body).to match(/view-toggle-btn--active.*List/)
      get arquivos_path(view: "grid")
      expect(response.body).to match(/view-toggle-btn--active.*Grid/)
    end

    it "renders pagination only when many pages exist" do
      starting = Arquivo.count
      pages_needed = (starting.to_f / 12).ceil
      if pages_needed <= 1
        get arquivos_path
        expect(response.body).not_to include('class="pagination"')
      end
    end

    it "renders extra page links when more arquivos are added" do
      before_count = Arquivo.count
      create_list(:arquivo, 13)
      get arquivos_path
      expect(response.body).to include('class="pagination"')
      expect(response.body).to include("page=2")
    end

    it "renders pagination in list view when many arquivos exist" do
      create_list(:arquivo, 51)
      get arquivos_path(view: "list")
      expect(response.body).to include('class="pagination"')
    end

    it "accepts page param and clamps to valid range" do
      get arquivos_path(page: 2)
      expect(response.body).to include('class="gallery"')
      get arquivos_path(page: 999)
      expect(response.body).to include('class="gallery"')
    end

    it "toggle links omit page param" do
      get arquivos_path(view: "grid", page: 3)
      expect(response.body).to match(%r{href="/arquivos\?view=list"})
      expect(response.body).to match(%r{href="/arquivos\?view=grid"})
    end
  end

  describe "GET / (upload form)" do
    it "renders the drop zone" do
      get root_path
      expect(response.body).to include("upload-dropzone")
      expect(response.body).to include("Drag & drop files here")
    end

    it "renders multi-file input with accepted formats" do
      get root_path
      expect(response.body).to include('multiple="multiple"')
      expect(response.body).to match(/accept="\.tif[^"]*"/)
    end

    it "renders Stimulus data attributes for upload controller" do
      get root_path
      expect(response.body).to include('data-controller="upload"')
      expect(response.body).to include('data-upload-target="dropzone"')
      expect(response.body).to include('data-upload-target="input"')
      expect(response.body).to include('data-upload-target="fileList"')
      expect(response.body).to include('data-upload-target="submit"')
    end
  end

  describe "POST /arquivos" do
    let(:file_params) do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("e2e/test-image.tif"),
        "image/tiff"
      )
      { arquivo: { original_file: file } }
    end

    it "creates an arquivo" do
      expect { post arquivos_path, params: file_params }.to change(Arquivo, :count).by(1)
    end

    # Regression: a batch upload without batch_size used to raise
    # ZeroDivisionError in UploadTimeEstimator and return 500.
    it "creates the arquivo when batch_started_at is sent without batch_size" do
      create(:arquivo, created_at: 10.minutes.ago)
      params = file_params.deep_merge(arquivo: { batch_started_at: Time.current.iso8601 })
      expect { post arquivos_path, params: params }.to change(Arquivo, :count).by(1)
      expect(response).to redirect_to(arquivos_path)
      expect(Arquivo.order(:created_at).last.estimated_seconds).to be_between(599, 601)
    end

    it "redirects to gallery" do
      post arquivos_path, params: file_params
      expect(response).to redirect_to(arquivos_path)
    end

    it "returns 422 when no file is submitted" do
      post arquivos_path, params: { arquivo: { filename: "test" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("select a file to upload")
    end

    it "extracts filename, extension and mime_type from uploaded file when not provided" do
      expect { post arquivos_path, params: file_params }.to change(Arquivo, :count).by(1)

      arquivo = Arquivo.last
      expect(arquivo.filename).to eq("test-image")
      expect(arquivo.extension).to eq("tif")
      expect(arquivo.mime_type).to eq("image/tiff")
    end

    it "accepts multi-frame TIFFs" do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("e2e/multi-frame-test.tif"),
        "image/tiff"
      )
      expect { post arquivos_path, params: { arquivo: { original_file: file } } }
        .to change(Arquivo, :count).by(1)
      expect(response).to redirect_to(arquivos_path)
    end

    it "rejects file when extension does not match actual format" do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("e2e/test-image.tif"),
        "image/jpeg"
      )
      params = { arquivo: { original_file: file, extension: "jpg" } }

      post arquivos_path, params: params
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects file with unsupported extension" do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("e2e/test-image.tif"),
        "image/tiff"
      )
      params = { arquivo: { original_file: file, extension: "docx" } }

      post arquivos_path, params: params
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /arquivos/:id/update_time" do
    it "updates annotated time and creates log" do
      arquivo = create(:arquivo, estimated_seconds: 120)
      expect {
        patch update_time_arquivo_path(arquivo), params: { annotated_seconds: 300 }
      }.to change(ArquivoTimeLog, :count).by(1)
      expect(arquivo.reload.annotated_seconds).to eq(300)
      expect(ArquivoTimeLog.last.user).to eq(@usuario_logado)
    end

    it "responds with turbo stream when requested" do
      arquivo = create(:arquivo, estimated_seconds: 120)
      patch update_time_arquivo_path(arquivo), params: { annotated_seconds: 300 }, as: :turbo_stream
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
      expect(response.body).to include("<turbo-stream")
    end
  end

  describe "PATCH /arquivos/:id/update_molde" do
    it "assigns molde, modelo and peca to an arquivo" do
      molde = create(:molde)
      modelo = create(:modelo)
      peca = create(:peca)
      arquivo = create(:arquivo)

      patch update_molde_arquivo_path(arquivo), params: { molde_uuid: molde.uuid, modelo_uuid: modelo.uuid, peca_uuid: peca.uuid }
      expect(response).to redirect_to(arquivo_path(arquivo))
      arquivo.reload
      expect(arquivo.molde_id).to eq(molde.id)
      expect(arquivo.modelo_id).to eq(modelo.id)
      expect(arquivo.peca_id).to eq(peca.id)
    end

    it "responds with turbo stream when requested" do
      molde = create(:molde)
      arquivo = create(:arquivo)

      patch update_molde_arquivo_path(arquivo), params: { molde_uuid: molde.uuid }, as: :turbo_stream
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
      expect(response.body).to include("<turbo-stream")
    end
  end

  describe "the automatic tamanho search (Etapa 0.6)" do
    # MoldMatchService took up to 37 s inside this request on dev data.
    it "update_molde only queues it and shows Procurando tamanho…" do
      ActiveJob::Base.queue_adapter = :test
      arquivo = create(:arquivo, client: create(:client))
      molde = create(:molde, client: arquivo.client)
      expect {
        patch update_molde_arquivo_path(arquivo), params: { molde_uuid: molde.uuid }, as: :turbo_stream
      }.to have_enqueued_job(TamanhoAutoAssignJob).with(arquivo.id)
      expect(arquivo.reload.buscando_tamanho?).to be true
      expect(response.body).to include("Procurando tamanho", busca_tamanho_arquivo_path(arquivo, format: :json))
    ensure
      ActiveJob::Base.queue_adapter = :inline
    end

    # Etapa 1.1 (5/5): choosing the molde reads Referência + Nome from the
    # file name (the referência is created in the molde when missing).
    it "fills the arte's referência and name from its file name" do
      ActiveJob::Base.queue_adapter = :test
      arquivo = create(:arquivo, category: "artes", filename: "19-BLUEY PTO-LINGUA")
      create(:peca, nome: "Língua")
      molde = create(:molde)
      patch update_molde_arquivo_path(arquivo), params: { molde_uuid: molde.uuid }
      expect([ arquivo.reload.referencia&.nome, arquivo.nome, arquivo.referencia&.molde ]).to eq([ "19", "BLUEY PTO", molde ])
    ensure
      ActiveJob::Base.queue_adapter = :inline
    end

    it "keeps a tamanho that is the new molde's own, and doesn't search" do
      ActiveJob::Base.queue_adapter = :test
      molde = create(:molde, modelo: create(:modelo))
      corte = create(:arquivo, :corte, organized: true, modelo: molde.modelo).tap { |c| c.moldes << molde }
      arquivo = create(:arquivo, tamanho: create(:tamanho, arquivo: corte))
      expect {
        patch update_molde_arquivo_path(arquivo), params: { molde_uuid: molde.uuid }
      }.not_to have_enqueued_job(TamanhoAutoAssignJob)
      expect(arquivo.reload.tamanho_id).to be_present
    ensure
      ActiveJob::Base.queue_adapter = :inline
    end

    # Regression (28/09/2026): changing 21-24 → 28-29 kept 21-24's tamanho,
    # because the automatic search never overrides a tamanho.
    it "changing to another molde drops the old molde's tamanho and searches again" do
      ActiveJob::Base.queue_adapter = :test
      modelo = create(:modelo)
      antigo, novo = create(:molde, modelo: modelo, sufixo: "21-24"), create(:molde, modelo: modelo, sufixo: "28-29")
      corte_antigo = create(:arquivo, :corte, organized: true, modelo: modelo).tap { |c| c.moldes << antigo }
      create(:arquivo, :corte, organized: true, modelo: modelo).tap { |c| c.moldes << novo }
      arquivo = create(:arquivo, molde: antigo, tamanho: create(:tamanho, arquivo: corte_antigo))
      expect {
        patch update_molde_arquivo_path(arquivo), params: { molde_uuid: novo.uuid }
      }.to have_enqueued_job(TamanhoAutoAssignJob)
      expect(arquivo.reload.tamanho_id).to be_nil
    ensure
      ActiveJob::Base.queue_adapter = :inline
    end

    it "unlinking the molde clears the tamanho and modelo too, without searching" do
      ActiveJob::Base.queue_adapter = :test
      molde = create(:molde, modelo: create(:modelo))
      corte = create(:arquivo, :corte, organized: true, modelo: molde.modelo).tap { |c| c.moldes << molde }
      arquivo = create(:arquivo, molde: molde, modelo: molde.modelo, tamanho: create(:tamanho, arquivo: corte))
      get arquivo_path(arquivo)
      expect(response.body).to include('title="Unlink mold"')
      expect {
        patch update_molde_arquivo_path(arquivo), params: { molde_uuid: "" }
      }.not_to have_enqueued_job(TamanhoAutoAssignJob)
      expect(arquivo.reload).to have_attributes(molde_id: nil, modelo_id: nil, tamanho_id: nil)
      expect(flash[:notice]).to eq("Molde unlinked.")
    ensure
      ActiveJob::Base.queue_adapter = :inline
    end

    it "busca_tamanho.json says when it is over (the page's polling safety net)" do
      arquivo = create(:arquivo, buscando_tamanho_desde: Time.current)
      get busca_tamanho_arquivo_path(arquivo, format: :json)
      expect(response.parsed_body).to eq("final" => false)
      arquivo.update_column(:buscando_tamanho_desde, nil)
      get busca_tamanho_arquivo_path(arquivo, format: :json)
      expect(response.parsed_body).to eq("final" => true)
    end

    # A job that died must not leave the page waiting forever.
    it "treats a search older than 10 minutes as over" do
      expect(create(:arquivo, buscando_tamanho_desde: 11.minutes.ago).buscando_tamanho?).to be false
    end
  end

  describe "PATCH /arquivos/:id/update_tamanho" do
    it "assigns a tamanho to an arquivo" do
      arquivo = create(:arquivo)
      tamanho = create(:tamanho, arquivo: arquivo)
      patch update_tamanho_arquivo_path(arquivo), params: { tamanho_uuid: tamanho.uuid }
      expect(response).to redirect_to(arquivo_path(arquivo))
      arquivo.reload
      expect(arquivo.tamanho_id).to eq(tamanho.id)
    end

    it "unlinks a tamanho from an arquivo" do
      tamanho = create(:tamanho)
      arquivo = create(:arquivo, tamanho: tamanho)
      patch update_tamanho_arquivo_path(arquivo), params: { tamanho_uuid: "" }
      expect(response).to redirect_to(arquivo_path(arquivo))
      arquivo.reload
      expect(arquivo.tamanho_id).to be_nil
    end

    it "responds with turbo stream when requested" do
      arquivo = create(:arquivo)
      tamanho = create(:tamanho, arquivo: arquivo)

      patch update_tamanho_arquivo_path(arquivo), params: { tamanho_uuid: tamanho.uuid }, as: :turbo_stream
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
      expect(response.body).to include("<turbo-stream")
    end
  end

  describe "PATCH /arquivos/:id/update_tipo_corte" do
    it "sets tipo_corte to apenas_corte" do
      arquivo = create(:arquivo, extension: "dxf", category: "corte")

      patch update_tipo_corte_arquivo_path(arquivo), params: { tipo_corte: "apenas_corte" }
      expect(response).to redirect_to(arquivo_path(arquivo))
      arquivo.reload
      expect(arquivo.tipo_corte).to eq("apenas_corte")
    end

    it "sets tipo_corte to corte_estampa" do
      arquivo = create(:arquivo, extension: "dxf", category: "corte", tipo_corte: "apenas_corte")

      patch update_tipo_corte_arquivo_path(arquivo), params: { tipo_corte: "corte_estampa" }
      expect(response).to redirect_to(arquivo_path(arquivo))
      arquivo.reload
      expect(arquivo.tipo_corte).to eq("corte_estampa")
    end

    it "responds with turbo stream when requested" do
      arquivo = create(:arquivo, extension: "dxf", category: "corte")

      patch update_tipo_corte_arquivo_path(arquivo), params: { tipo_corte: "apenas_corte" }, as: :turbo_stream
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
      expect(response.body).to include("<turbo-stream")
    end
  end

  describe "GET /arquivos/:id/preview" do
    it "returns 404 when no preview file exists" do
      arquivo = create(:arquivo)
      get preview_arquivo_path(arquivo)
      expect(response).to have_http_status(:not_found)
    end

    it "serves the preview image" do
      arquivo = create(:arquivo)
      version = create(:arquivo_version, arquivo: arquivo, approved: true)
      arquivo.update!(approved_version_id: version.id)
      preview_path = File.join(version.storage_dir, "preview.png")
      FileUtils.mkdir_p(File.dirname(preview_path))
      File.write(preview_path, "fake-png-data")
      version.update!(preview_file: preview_path)

      get preview_arquivo_path(arquivo)
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("image/png")
    end
  end

  describe "GET /arquivos/:id/download" do
    # Etapa 1.1 (5/5): an arte with a molde downloads under its full name,
    # without accents.
    it "names an arte's file by its full name" do
      tamanho = create(:tamanho, arquivo: create(:arquivo, :corte, peca: create(:peca, nome: "Língua")), nome: "29-30")
      molde = create(:molde, modelo: create(:modelo, abreviacao: "TNS"))
      arte = create(:arquivo, category: "artes", molde: molde, nome: "Coração", tamanho: tamanho,
                              referencia: create(:referencia, molde: molde, nome: "19"))
      versao = create(:arquivo_version, arquivo: arte, version_number: 1, approved: true, extension: "tif", original_file: "x.tif")
      FileUtils.mkdir_p(File.dirname(versao.original_path))
      File.write(versao.original_path, "tif")
      arte.update!(approved_version: versao)

      get download_arquivo_path(arte)
      expect(response.headers["Content-Disposition"]).to include('filename="001-TNS_19_Coracao_Lingua_29-30.tif"')
    end

    it "returns 404 when no approved version exists" do
      arquivo = create(:arquivo)
      get download_arquivo_path(arquivo)
      expect(response).to have_http_status(:not_found)
    end

    it "downloads the approved file" do
      arquivo = create(:arquivo, extension: "dxf")
      version = create(:arquivo_version, arquivo: arquivo, approved: true, extension: "dxf", original_file: "test.dxf")
      arquivo.update!(approved_version_id: version.id)
      original_dir = File.join(version.storage_dir, "original")
      FileUtils.mkdir_p(original_dir)
      File.write(File.join(original_dir, "test.dxf"), "fake-dxf-content")

      get download_arquivo_path(arquivo)
      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Disposition"]).to include("attachment")
    end
  end

  # Etapa 2.2 (1/3, decided 08/10/2026): the corte page's "Giro no encaixe".
  describe "PATCH /arquivos/:id/update_giro" do
    it "saves how the corte's pieces may turn, from the corte page" do
      corte = create(:arquivo, :corte, organized: true)
      get arquivo_path(corte)
      html = Nokogiri::HTML(response.body)
      expect(html.css(".giro-corte input[name=giro_no_encaixe]").map { |r| [ r["value"], r.key?("checked") ] })
        .to eq([ [ "nenhum", false ], [ "180", false ], [ "90", false ] ])
      expect(html.at_css(".giro-corte-pendente").text).to include("Giro não marcado")
      patch update_giro_arquivo_path(corte), params: { giro: "90" }
      expect([ corte.reload.giro, flash[:notice] ]).to eq([ "90", "Giro no encaixe: 90°. Recalculando o consumo dos tamanhos." ])
    end

    it "shows each size's pieces per meter of fabric in the size list" do
      corte = create(:arquivo, :corte, organized: true)
      create(:tamanho, arquivo: corte, nome: "29-30", metros_por_peca: { "1400" => 0.02 })
      get arquivo_path(corte)
      expect(Nokogiri::HTML(response.body).at_css(".tamanho-list--readonly .tamanho-consumo").text.squish).to eq("1,40 m: 50,0 peças/m")
    end

    # The radios sit inside the organize form: a <form> of their own would
    # close it (AGENTS.md "Nested forms gotcha"); they save by fetch, as JSON.
    it "is right above the size list, inside the organize form without a form of its own, and answers JSON" do
      corte = create(:arquivo, :corte, organized: true)
      create(:tamanho, arquivo: corte)
      get arquivo_path(corte)
      html = Nokogiri::HTML(response.body)
      expect(html.at_css("form.mold-organization-form #giro-corte-section form")).to be_nil
      expect(html.at_css("#giro-corte-section").next_element["class"]).to include("tamanho-list--readonly")
      patch update_giro_arquivo_path(corte), params: { giro: "180" }, as: :json
      expect([ response.parsed_body, flash[:notice] ]).to eq([ { "ok" => true, "giro" => "180" }, "Giro no encaixe: 180°. Recalculando o consumo dos tamanhos." ])
      patch update_giro_arquivo_path(corte), params: { giro: "45" }, as: :json
      expect([ response.status, response.parsed_body["error"] ]).to eq([ 422, "Giro 45 is not a turn; expected nenhum, 180 or 90" ])
    end

    # Decided 08/10/2026: an organized corte warns until its turn is marked.
    it "warns on the gallery card until the turn is marked" do
      corte = create(:arquivo, :corte, organized: true)
      get arquivos_path
      expect(Nokogiri::HTML(response.body).at_css("#arquivo_#{corte.uuid} img[alt='Giro não marcado']")).to be_present
      corte.update!(giro: "90")
      get arquivos_path
      expect(Nokogiri::HTML(response.body).at_css("#arquivo_#{corte.uuid} img[alt='Giro não marcado']")).to be_nil
    end

    it "refuses a turn that isn't one, and an arte" do
      corte = create(:arquivo, :corte)
      patch update_giro_arquivo_path(corte), params: { giro: "45" }
      expect([ corte.reload.giro, flash[:alert] ]).to eq([ nil, "Giro 45 is not a turn; expected nenhum, 180 or 90" ])
      patch update_giro_arquivo_path(create(:arquivo)), params: { giro: "90" }
      expect(flash[:alert]).to eq("Only a corte has a turn in the fit.")
    end
  end

  describe "POST /arquivos/:id/upload_version" do
    it "uploads a new version and redirects" do
      arquivo = create(:arquivo, extension: "tif")
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("e2e/test-image.tif"),
        "image/tiff"
      )

      expect {
        post upload_version_arquivo_path(arquivo), params: { original_file: file }
      }.to change(arquivo.arquivo_versions, :count).by(1)
      expect(response).to redirect_to(arquivo_path(arquivo))
    end

    it "returns alert when no file is provided" do
      arquivo = create(:arquivo)
      post upload_version_arquivo_path(arquivo), params: {}
      expect(response).to redirect_to(arquivo_path(arquivo))
    end
  end

  describe "PATCH /arquivos/:id/approve_version" do
    it "marks a version as approved" do
      arquivo = create(:arquivo)
      v1 = create(:arquivo_version, arquivo: arquivo, approved: true, version_number: 1)
      arquivo.update!(approved_version_id: v1.id)
      v2 = create(:arquivo_version, arquivo: arquivo, approved: false, version_number: 2)

      patch approve_version_arquivo_path(arquivo), params: { version_uuid: v2.uuid }
      expect(response).to redirect_to(arquivo_path(arquivo))
      expect(v1.reload.approved).to be false
      expect(v2.reload.approved).to be true
      expect(arquivo.reload.approved_version_id).to eq(v2.id)
    end
  end

  describe "GET /arquivos/:id/version_preview" do
    it "returns 404 when version has no preview" do
      arquivo = create(:arquivo)
      version = create(:arquivo_version, arquivo: arquivo)
      get version_preview_arquivo_path(arquivo, version_uuid: version.uuid)
      expect(response).to have_http_status(:not_found)
    end

    it "serves the version preview image" do
      arquivo = create(:arquivo)
      version = create(:arquivo_version, arquivo: arquivo)
      preview_path = File.join(version.storage_dir, "preview.png")
      FileUtils.mkdir_p(File.dirname(preview_path))
      File.write(preview_path, "fake-png-data")
      version.update!(preview_file: preview_path)

      get version_preview_arquivo_path(arquivo, version_uuid: version.uuid)
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("image/png")
    end
  end

  describe "PATCH /arquivos/:id/configure_layers" do
    it "saves layer annotations and redirects" do
      arquivo = create(:arquivo, extension: "dxf")
      version = create(:arquivo_version, arquivo: arquivo, approved: true, extension: "dxf")
      arquivo.update!(approved_version_id: version.id)

      patch configure_layers_arquivo_path(arquivo), params: {
        version_uuid: version.uuid,
        layer_annotations: {
          "0" => { color: "#FF0000", layer_name: "Layer1", annotation: "cut" }
        }
      }
      expect(response).to redirect_to(arquivo_path(arquivo))
      expect(version.cut_layers.count).to eq(1)
      expect(version.cut_layers.first.annotation).to eq("cut")
    end
  end

  describe "preparing a corte's tamanhos in the queue (Etapa 0.6)" do
    around do |example|
      anterior = ActiveJob::Base.queue_adapter
      ActiveJob::Base.queue_adapter = :test
      example.run
    ensure
      ActiveJob::Base.queue_adapter = anterior
    end

    let(:organizar) do
      { modelo_uuid: create(:modelo).uuid, peca_uuid: create(:peca).uuid, tamanhos: { "0" => { nome: "34", width_mm: 100, height_mm: 50 } } }
    end

    it "organize saves the choice at once and only queues each size's DXF and preview" do
      arquivo = create(:arquivo, extension: "dxf")
      expect {
        patch organize_arquivo_path(arquivo), params: organizar, as: :turbo_stream
      }.to have_enqueued_job(PreparacaoTamanhosJob).with(arquivo.id, false)
      expect(arquivo.reload.tamanhos.pluck(:nome)).to eq([ "34" ])
      expect(response.body).to include("Preparando os tamanhos", preparacao_tamanhos_arquivo_path(arquivo, format: :json))
    end

    it "re-detects in the queue when organizing had failed" do
      arquivo = create(:arquivo, extension: "dxf", organize_error: "file has 1 or more stacked cuts")
      expect {
        patch organize_arquivo_path(arquivo), params: organizar
      }.to have_enqueued_job(PreparacaoTamanhosJob).with(arquivo.id, true)
    end

    it "preparacao_tamanhos.json says when it is over (the page's polling safety net)" do
      arquivo = create(:arquivo, :corte, preparando_tamanhos_desde: Time.current)
      get preparacao_tamanhos_arquivo_path(arquivo, format: :json)
      expect(response.parsed_body).to eq("final" => false)
      arquivo.update_column(:preparando_tamanhos_desde, 11.minutes.ago)
      get preparacao_tamanhos_arquivo_path(arquivo, format: :json)
      expect(response.parsed_body).to eq("final" => true)
    end
  end

  describe "PATCH /arquivos/:id/organize" do
    it "marks as organized and creates tamanhos" do
      modelo = create(:modelo)
      peca = create(:peca)
      arquivo = create(:arquivo, extension: "dxf")

      patch organize_arquivo_path(arquivo), params: {
        modelo_uuid: modelo.uuid,
        peca_uuid: peca.uuid,
        modelo_nome: "Test Modelo",
        peca_nome: "Test Peca",
        tamanhos: {
          "0" => { nome: "Size A", width_mm: 100, height_mm: 50 }
        }
      }
      expect(response).to redirect_to(arquivo_path(arquivo))
      arquivo.reload
      expect(arquivo.organized).to be true
      expect(arquivo.tamanhos.count).to eq(1)
      expect(arquivo.tamanhos.first.nome).to eq("Size A")
    end

    it "responds with turbo stream when requested" do
      modelo = create(:modelo)
      peca = create(:peca)
      arquivo = create(:arquivo, extension: "dxf")

      patch organize_arquivo_path(arquivo), params: {
        modelo_uuid: modelo.uuid,
        peca_uuid: peca.uuid,
        tamanhos: { "0" => { nome: "Size A", width_mm: 100, height_mm: 50 } }
      }, as: :turbo_stream
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
      expect(response.body).to include("<turbo-stream")
    end

    it "saves the grade type and each size's individual sizes (Etapa 1.2, 1/3)" do
      arquivo = create(:arquivo, :corte)
      create(:tamanho, arquivo: arquivo, position: 1, nome: "Size 1")

      patch organize_arquivo_path(arquivo), params: { tipo_grade: "pmg", tamanhos: { "0" => { rotulo: "p", tamanhos: "33-34" } } }
      tamanho = arquivo.tamanhos.reload.first
      expect([ arquivo.reload.tipo_grade, tamanho.nome, tamanho.numeros ]).to eq([ "pmg", "P", %w[33 34] ])
    end

    it "refuses sizes that don't fit the grade type and saves nothing" do
      peca = create(:peca)
      arquivo = create(:arquivo, :corte)
      create(:tamanho, arquivo: arquivo, position: 1, nome: "24")

      patch organize_arquivo_path(arquivo), params: { peca_uuid: peca.uuid, tipo_grade: "par", tamanhos: { "0" => { tamanhos: "24-25" } } }
      follow_redirect!
      expect(response.body).to include("Size 1: &quot;24-25&quot; isn&#39;t a Par pair")
      expect([ arquivo.reload.organized, arquivo.peca_id, arquivo.tipo_grade, arquivo.tamanhos.pluck(:nome) ]).to eq([ false, nil, nil, [ "24" ] ])
    end

    it "refuses an unknown grade type" do
      arquivo = create(:arquivo, :corte)
      patch organize_arquivo_path(arquivo), params: { tipo_grade: "dupla" }
      expect(arquivo.reload.tipo_grade).to be_nil
    end

    it "allows organize when peca taken but arquivo has no linked moldes" do
      molde = create(:molde)
      modelo = create(:modelo)
      peca = create(:peca)

      corte1 = create(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)
      corte1.moldes << molde

      corte2 = create(:arquivo, :corte)

      patch organize_arquivo_path(corte2), params: {
        modelo_uuid: modelo.uuid,
        peca_uuid: peca.uuid
      }
      expect(response).to redirect_to(arquivo_path(corte2))
      corte2.reload
      expect(corte2.peca_id).to eq(peca.id)
      expect(corte2.organized).to be true
    end

    it "rejects organize when peca already used and arquivo already has the molde linked" do
      molde = create(:molde)
      modelo = create(:modelo)
      peca = create(:peca)

      corte1 = create(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)
      corte1.moldes << molde

      corte2 = create(:arquivo, :corte)
      corte2.moldes << molde

      patch organize_arquivo_path(corte2), params: {
        modelo_uuid: modelo.uuid,
        peca_uuid: peca.uuid
      }
      expect(response).to redirect_to(arquivo_path(corte2))
      follow_redirect!
      expect(response.body).to include("já possui um corte")
      corte2.reload
      expect(corte2.organized).to be false
    end

    it "rejects organize via turbo_stream when peca already used" do
      molde = create(:molde)
      modelo = create(:modelo)
      peca = create(:peca)

      corte1 = create(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)
      corte1.moldes << molde

      corte2 = create(:arquivo, :corte)
      corte2.moldes << molde

      patch organize_arquivo_path(corte2), params: {
        modelo_uuid: modelo.uuid,
        peca_uuid: peca.uuid
      }, as: :turbo_stream
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
      expect(response.body).to include("já possui um corte")
      expect(response.body).to include('id="organize-flash"')
      corte2.reload
      expect(corte2.organized).to be false
    end
  end

  describe "POST /arquivos/:id/add_molde" do
    it "rejects when peca already taken for the molde" do
      molde = create(:molde)
      modelo = create(:modelo)
      peca = create(:peca)

      corte1 = create(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)
      corte1.moldes << molde

      corte2 = create(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)

      post add_molde_arquivo_path(corte2), params: { molde_uuid: molde.uuid }
      expect(response).to redirect_to(arquivo_path(corte2))
      follow_redirect!
      expect(response.body).to include("já possui corte organizado")
    end

    it "adds molde when no conflict" do
      molde = create(:molde)
      corte = create(:arquivo, :corte)

      post add_molde_arquivo_path(corte), params: { molde_uuid: molde.uuid }
      expect(response).to redirect_to(arquivo_path(corte))
      expect(corte.reload.moldes).to include(molde)
    end

    it "rejects via turbo_stream when peca already taken for the molde" do
      molde = create(:molde)
      modelo = create(:modelo)
      peca = create(:peca)

      corte1 = create(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)
      corte1.moldes << molde

      corte2 = create(:arquivo, :corte, organized: true, peca: peca, modelo: modelo)

      post add_molde_arquivo_path(corte2), params: { molde_uuid: molde.uuid }, as: :turbo_stream
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
      expect(response.body).to include("já possui corte organizado")
      expect(response.body).to include('id="molde-flash"')
      expect(corte2.reload.moldes).not_to include(molde)
    end

    it "adds molde via turbo_stream when no conflict" do
      molde = create(:molde)
      corte = create(:arquivo, :corte)

      post add_molde_arquivo_path(corte), params: { molde_uuid: molde.uuid }, as: :turbo_stream
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
      expect(response.body).to include('id="molde-field-section"')
      expect(corte.reload.moldes).to include(molde)
    end
  end

  describe "DELETE /arquivos/:id" do
    # Etapa 0.4: moves to the trash; the row and its files stay.
    it "moves the arquivo to the trash without deleting the row" do
      arquivo = create(:arquivo)
      expect { delete arquivo_path(arquivo) }.not_to change(Arquivo, :count)
      expect(arquivo.reload).to be_excluido
      expect(arquivo.exclusao_logs.last).to have_attributes(acao: "excluido", changed_by: "127.0.0.1")
    end

    it "redirects to gallery" do
      arquivo = create(:arquivo)
      delete arquivo_path(arquivo)
      expect(response).to redirect_to(arquivos_path)
    end

    it "keeps the storage folder so it can be restored" do
      arquivo = create(:arquivo)
      folder = ArquivosController::STORAGE_BASE.join(arquivo.uuid)
      FileUtils.mkdir_p(folder)

      delete arquivo_path(arquivo)

      expect(File).to exist(folder)
    ensure
      FileUtils.rm_rf(folder) if folder
    end

    # Used to be refused (real FK from arquivos.tamanho_id); a trashed corte
    # keeps its tamanhos, so the linked arte stays intact.
    it "trashes a corte whose tamanho is still linked, keeping the link" do
      corte = create(:arquivo, :corte)
      tamanho = create(:tamanho, arquivo: corte)
      arte = create(:arquivo, tamanho: tamanho)

      delete arquivo_path(corte)

      expect(corte.reload).to be_excluido
      expect(arte.reload.tamanho).to eq(tamanho)
    end

    it "hides the trashed arquivo from the gallery but keeps its page with a badge" do
      arquivo = create(:arquivo, filename: "some-trashed-arte")
      delete arquivo_path(arquivo)

      get arquivos_path
      expect(response.body).not_to include("some-trashed-arte")
      get arquivo_path(arquivo)
      expect(response.body).to include("badge-excluido")
      expect(response.body).not_to include("Delete Arquivo")
    end
  end

  describe "DELETE /arquivos/batch_destroy" do
    it "moves multiple arquivos to the trash by uuid" do
      a1 = create(:arquivo)
      a2 = create(:arquivo)
      expect {
        delete batch_destroy_arquivos_path, params: { ids: [ a1.uuid, a2.uuid ] }, as: :json
      }.to change(Arquivo.excluidos, :count).by(2)
      expect(Arquivo.count).to eq(2)
    end

    it "returns json with destroyed count" do
      a1 = create(:arquivo)
      a2 = create(:arquivo)
      delete batch_destroy_arquivos_path, params: { ids: [ a1.uuid, a2.uuid ] }, as: :json
      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body["destroyed"]).to eq(2)
      expect(body["errors"]).to eq([])
    end

    it "handles nonexistent uuids gracefully" do
      a1 = create(:arquivo)
      delete batch_destroy_arquivos_path, params: { ids: [ a1.uuid, "nonexistent" ] }, as: :json
      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body["destroyed"]).to eq(1)
      expect(body["errors"]).to eq([ "nonexistent" ])
    end

    it "returns 422 when ids is empty" do
      delete batch_destroy_arquivos_path, params: { ids: [] }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "returns 422 when ids is missing" do
      delete batch_destroy_arquivos_path, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "trashes arquivos with complex FK relationships, keeping their children" do
      a = create(:arquivo)
      v = create(:arquivo_version, arquivo: a, version_number: 1, status: :processed)
      a.update!(approved_version_id: v.id)
      create(:tamanho, arquivo: a)

      delete batch_destroy_arquivos_path, params: { ids: [ a.uuid ] }, as: :json

      expect(response.parsed_body).to eq("destroyed" => 1, "errors" => [])
      expect(a.reload).to have_attributes(excluido?: true, approved_version_id: v.id)
      expect(a.tamanhos.count).to eq(1)
    end

    it "keeps each trashed arquivo's storage folder" do
      a1 = create(:arquivo)
      folder = ArquivosController::STORAGE_BASE.join(a1.uuid)
      FileUtils.mkdir_p(folder)

      delete batch_destroy_arquivos_path, params: { ids: [ a1.uuid ] }, as: :json

      expect(File).to exist(folder)
    ensure
      FileUtils.rm_rf(folder) if folder
    end

    it "reports an arquivo already in the trash as not found" do
      trashed = create(:arquivo, deleted_at: 1.day.ago)
      delete batch_destroy_arquivos_path, params: { ids: [ trashed.uuid ] }, as: :json
      expect(response.parsed_body).to eq("destroyed" => 0, "errors" => [ trashed.uuid ])
    end

    it "renders the batch toolbar data attributes on index page" do
      create(:arquivo)
      get arquivos_path
      expect(response.body).to include('data-controller="batch-select"')
      expect(response.body).to include('data-batch-select-target="toolbar"')
      expect(response.body).to include('data-batch-select-target="count"')
      expect(response.body).to include('data-batch-select-target="deleteButton"')
    end
  end

  describe "GET /arquivos/:id/composicao" do
    let(:lateral) { create(:peca, nome: "Lateral") }
    let(:lingua) { create(:peca, nome: "Língua") }
    let(:molde) { create(:molde, partes: [ lateral, lingua ]) }

    it "lists every piece of the arte's molde, pending ones without arte" do
      arte = create(:arquivo, molde: molde, peca: lateral, filename: "lateral-azul")
      get composicao_arquivo_path(arte)
      expect(response).to have_http_status(:success)
      expect(response.parsed_body["pecas"]).to eq([
        { "peca_nome" => "Lateral", "arquivo_uuid" => arte.uuid, "filename" => "lateral-azul",
          "preview_url" => nil, "pendente" => false, "adicionada" => true },
        { "peca_nome" => "Língua", "arquivo_uuid" => nil, "filename" => nil,
          "preview_url" => nil, "pendente" => true, "adicionada" => false }
      ])
    end

    it "links the preview of pieces that have one" do
      arte = create(:arquivo, molde: molde, peca: lateral)
      create(:arquivo_version, arquivo: arte, preview_file: "/tmp/p.png").tap { |v| arte.update!(approved_version: v) }
      get composicao_arquivo_path(arte)
      expect(response.parsed_body["pecas"].first["preview_url"]).to eq(preview_arquivo_path(arte))
    end

    it "returns 404 for an unknown arte" do
      get composicao_arquivo_path("nope")
      expect(response).to have_http_status(:not_found)
    end
  end

  # Characterization of upload validation (moved to ArquivoUploadService):
  # these pass unchanged against the pre-extraction controller.
  describe "upload validation" do
    let(:fake_tif) do
      path = Rails.root.join("tmp/upload-req-fake.tif").to_s
      system("convert", "-size", "10x10", "xc:red", "PNG:#{path}", exception: true)
      Rack::Test::UploadedFile.new(path, "image/tiff")
    end

    after { FileUtils.rm_f(Rails.root.join("tmp/upload-req-fake.tif")) }

    it "POST /arquivos rejects an extension that doesn't match the real format with 422" do
      expect { post arquivos_path, params: { arquivo: { original_file: fake_tif } } }.not_to change(Arquivo, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("declared &#39;TIF&#39; but file is &#39;PNG&#39;")
    end

    it "POST upload_version rejects an invalid file type without creating a version" do
      arquivo = create(:arquivo)
      create(:arquivo_version, arquivo: arquivo, version_number: 1)
      expect { post upload_version_arquivo_path(arquivo), params: { original_file: fake_tif } }.not_to change(ArquivoVersion, :count)
      expect(response).to redirect_to(arquivo_path(arquivo))
      expect(flash[:alert]).to eq("Invalid file type.")
    end
  end
end
