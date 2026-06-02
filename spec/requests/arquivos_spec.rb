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
    end

    it "responds with turbo stream when requested" do
      arquivo = create(:arquivo, estimated_seconds: 120)
      patch update_time_arquivo_path(arquivo), params: { annotated_seconds: 300 }, as: :turbo_stream
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
      expect(response.body).to include("<turbo-stream")
    end
  end

  describe "PATCH /arquivos/:id/update_modelo" do
    it "assigns modelo, molde and peca to an arquivo" do
      modelo = create(:modelo)
      molde = create(:molde)
      peca = create(:peca)
      arquivo = create(:arquivo)

      patch update_modelo_arquivo_path(arquivo), params: { modelo_id: modelo.id, molde_id: molde.id, peca_id: peca.id }
      expect(response).to redirect_to(arquivo_path(arquivo))
      arquivo.reload
      expect(arquivo.modelo_id).to eq(modelo.id)
      expect(arquivo.molde_id).to eq(molde.id)
      expect(arquivo.peca_id).to eq(peca.id)
    end

    it "responds with turbo stream when requested" do
      modelo = create(:modelo)
      arquivo = create(:arquivo)

      patch update_modelo_arquivo_path(arquivo), params: { modelo_id: modelo.id }, as: :turbo_stream
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
      expect(response.body).to include("<turbo-stream")
    end
  end

  describe "PATCH /arquivos/:id/update_tamanho" do
    it "assigns a tamanho to an arquivo" do
      arquivo = create(:arquivo)
      tamanho = create(:tamanho, arquivo: arquivo)
      patch update_tamanho_arquivo_path(arquivo), params: { tamanho_id: tamanho.id }
      expect(response).to redirect_to(arquivo_path(arquivo))
      arquivo.reload
      expect(arquivo.tamanho_id).to eq(tamanho.id)
    end

    it "unlinks a tamanho from an arquivo" do
      tamanho = create(:tamanho)
      arquivo = create(:arquivo, tamanho: tamanho)
      patch update_tamanho_arquivo_path(arquivo), params: { tamanho_id: "" }
      expect(response).to redirect_to(arquivo_path(arquivo))
      arquivo.reload
      expect(arquivo.tamanho_id).to be_nil
    end

    it "responds with turbo stream when requested" do
      arquivo = create(:arquivo)
      tamanho = create(:tamanho, arquivo: arquivo)

      patch update_tamanho_arquivo_path(arquivo), params: { tamanho_id: tamanho.id }, as: :turbo_stream
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

      patch approve_version_arquivo_path(arquivo), params: { version_id: v2.id }
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
      get version_preview_arquivo_path(arquivo, version_id: version.id)
      expect(response).to have_http_status(:not_found)
    end

    it "serves the version preview image" do
      arquivo = create(:arquivo)
      version = create(:arquivo_version, arquivo: arquivo)
      preview_path = File.join(version.storage_dir, "preview.png")
      FileUtils.mkdir_p(File.dirname(preview_path))
      File.write(preview_path, "fake-png-data")
      version.update!(preview_file: preview_path)

      get version_preview_arquivo_path(arquivo, version_id: version.id)
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
        version_id: version.id,
        layer_annotations: {
          "0" => { color: "#FF0000", layer_name: "Layer1", annotation: "cut" }
        }
      }
      expect(response).to redirect_to(arquivo_path(arquivo))
      expect(version.cut_layers.count).to eq(1)
      expect(version.cut_layers.first.annotation).to eq("cut")
    end
  end

  describe "PATCH /arquivos/:id/organize" do
    it "marks as organized and creates tamanhos" do
      molde = create(:molde)
      peca = create(:peca)
      arquivo = create(:arquivo, extension: "dxf")

      patch organize_arquivo_path(arquivo), params: {
        molde_id: molde.id,
        peca_id: peca.id,
        molde_nome: "Test Molde",
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
      molde = create(:molde)
      peca = create(:peca)
      arquivo = create(:arquivo, extension: "dxf")

      patch organize_arquivo_path(arquivo), params: {
        molde_id: molde.id,
        peca_id: peca.id,
        tamanhos: { "0" => { nome: "Size A", width_mm: 100, height_mm: 50 } }
      }, as: :turbo_stream
      expect(response).to have_http_status(:success)
      expect(response.content_type).to include("text/vnd.turbo-stream.html")
      expect(response.body).to include("<turbo-stream")
    end
  end

  describe "DELETE /arquivos/:id" do
    it "destroys the arquivo" do
      arquivo = create(:arquivo)
      expect { delete arquivo_path(arquivo) }.to change(Arquivo, :count).by(-1)
    end

    it "redirects to gallery" do
      arquivo = create(:arquivo)
      delete arquivo_path(arquivo)
      expect(response).to redirect_to(arquivos_path)
    end
  end

  describe "DELETE /arquivos/batch_destroy" do
    it "destroys multiple arquivos by uuid" do
      a1 = create(:arquivo)
      a2 = create(:arquivo)
      expect {
        delete batch_destroy_arquivos_path, params: { ids: [ a1.uuid, a2.uuid ] }, as: :json
      }.to change(Arquivo, :count).by(-2)
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

    it "destroys arquivos with complex FK relationships" do
      a = create(:arquivo)
      v = create(:arquivo_version, arquivo: a, version_number: 1, status: :processed)
      a.update!(approved_version_id: v.id)
      ArquivoImageMetadata.create!(arquivo_version: v, icc_profile: "sRGB", width_px: 100, height_px: 100)
      CutLayer.create!(arquivo_version: v, layer_name: "L1", color: "#000", annotation: "cut")
      create(:arquivo_time_log, arquivo: a)
      create(:tamanho, arquivo: a)

      expect {
        delete batch_destroy_arquivos_path, params: { ids: [ a.uuid ] }, as: :json
      }.to change(Arquivo, :count).by(-1)
      expect(response).to have_http_status(:success)
      body = response.parsed_body
      expect(body["destroyed"]).to eq(1)
      expect(body["errors"]).to eq([])
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
end
