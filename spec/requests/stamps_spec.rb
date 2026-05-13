require "rails_helper"

RSpec.describe "Stamps", type: :request do
  describe "GET /" do
    it "returns http success" do
      get root_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /stamps/:id" do
    it "returns http success for existing stamp" do
      stamp = create(:stamp)
      get stamp_path(stamp)
      expect(response).to have_http_status(:success)
    end

    it "returns 404 for nonexistent stamp" do
      get stamp_path("nonexistent")
      expect(response).to have_http_status(:not_found)
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

  describe "POST /stamps" do
    let(:file_params) do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("e2e/test-image.tif"),
        "image/tiff"
      )
      { stamp: { original_file: file } }
    end

    it "creates a stamp" do
      expect { post stamps_path, params: file_params }.to change(Stamp, :count).by(1)
    end

    it "redirects to gallery" do
      post stamps_path, params: file_params
      expect(response).to redirect_to(stamps_path)
    end

    it "processes the stamp synchronously" do
      expect_any_instance_of(StampProcessingJob).to receive(:perform).once.and_call_original
      post stamps_path, params: file_params
    end

    it "returns 422 when no file is submitted" do
      post stamps_path, params: { stamp: { filename: "test" } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("select a file to upload")
    end

    it "extracts filename, extension and mime_type from uploaded file when not provided" do
      expect { post stamps_path, params: file_params }.to change(Stamp, :count).by(1)

      stamp = Stamp.last
      expect(stamp.filename).to eq("test-image")
      expect(stamp.extension).to eq("tif")
      expect(stamp.mime_type).to eq("image/tiff")
      expect(stamp.status).to eq("processed")
      expect(stamp.preview_file).not_to be_nil
      expect(File.exist?(stamp.preview_file)).to be true
    end

    it "accepts multi-frame TIFFs" do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("e2e/multi-frame-test.tif"),
        "image/tiff"
      )
      expect { post stamps_path, params: { stamp: { original_file: file } } }
        .to change(Stamp, :count).by(1)
      expect(response).to redirect_to(stamps_path)
    end

    it "rejects file when extension does not match actual format" do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("e2e/test-image.tif"),
        "image/jpeg"
      )
      params = { stamp: { original_file: file, extension: "jpg" } }

      post stamps_path, params: params
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "rejects file with unsupported extension" do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("e2e/test-image.tif"),
        "image/tiff"
      )
      params = { stamp: { original_file: file, extension: "docx" } }

      post stamps_path, params: params
      expect(response).to have_http_status(:unprocessable_content)
    end

    describe "estimated_seconds" do
      before do
        Stamp.delete_all
        create(:stamp, created_at: reference_time)
      end

      let(:reference_time) { 10.minutes.ago }
      let(:file) { Rack::Test::UploadedFile.new(Rails.root.join("e2e/test-image.tif"), "image/tiff") }

      it "sets 0 when no previous stamp exists" do
        Stamp.delete_all
        params = { stamp: { original_file: file, batch_started_at: reference_time.iso8601, batch_size: 1 } }
        post stamps_path, params: params
        expect(Stamp.last.estimated_seconds).to eq(0)
      end

      it "sets interval divided by batch_size when previous stamp exists" do
        params = { stamp: { original_file: file, batch_started_at: Time.current.iso8601, batch_size: 4 } }
        post stamps_path, params: params
        # interval ~= 10.minutes = 600s, /4 = ~150
        expect(Stamp.last.estimated_seconds).to be_between(140, 160)
      end

      it "stays 0 when no batch params are sent" do
        post stamps_path, params: { stamp: { original_file: file } }
        expect(Stamp.last.estimated_seconds).to eq(0)
      end
    end

    describe "category assignment" do
      it "assigns artes category for TIFF files" do
        file = Rack::Test::UploadedFile.new(Rails.root.join("e2e/test-image.tif"), "image/tiff")
        post stamps_path, params: { stamp: { original_file: file } }
        expect(Stamp.last.category).to eq("artes")
      end

      it "assigns corte category for SVG files" do
        file = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/test.svg"), "image/svg+xml")
        post stamps_path, params: { stamp: { original_file: file } }
        expect(Stamp.last.category).to eq("corte")
      end

      it "assigns artes category for EPS files" do
        file = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/eps-rgb.eps"), "application/postscript")
        post stamps_path, params: { stamp: { original_file: file } }
        expect(Stamp.last.category).to eq("artes")
      end
    end
  end

  describe "GET / (gallery) with stale preview" do
    it "shows Preview unavailable when preview_file is set but file is missing" do
      stamp = create(:stamp, preview_file: "/tmp/nonexistent-preview.png")
      get root_path
      expect(response.body).to include("Preview unavailable")
    end

    it "shows status when processing failed" do
      stamp = create(:stamp, status: :failed)
      get root_path
      expect(response.body).to include("Failed")
    end
  end

  describe "GET /.well-known/*path" do
    it "returns 204 for Chrome DevTools probe" do
      get "/.well-known/appspecific/com.chrome.devtools.json"
      expect(response).to have_http_status(:no_content)
    end
  end

  describe "PATCH /stamps/:id/update_time" do
    it "updates annotated time and creates log" do
      stamp = create(:stamp, estimated_seconds: 120)
      expect {
        patch update_time_stamp_path(stamp), params: { annotated_seconds: 300 }
      }.to change(StampTimeLog, :count).by(1)
      expect(stamp.reload.annotated_seconds).to eq(300)
    end
  end

  describe "DELETE /stamps/:id" do
    it "destroys the stamp" do
      stamp = create(:stamp)
      expect { delete stamp_path(stamp) }.to change(Stamp, :count).by(-1)
    end

    it "redirects to gallery" do
      stamp = create(:stamp)
      delete stamp_path(stamp)
      expect(response).to redirect_to(stamps_path)
    end
  end
end
