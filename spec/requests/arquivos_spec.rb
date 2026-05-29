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
end
