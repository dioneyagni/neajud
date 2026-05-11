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
      expect(response).to have_http_status(:unprocessable_entity)
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

    it "rejects file when extension does not match actual format" do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("e2e/test-image.tif"),
        "image/jpeg"
      )
      params = { stamp: { original_file: file, extension: "jpg" } }

      post stamps_path, params: params
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "rejects file with unsupported extension" do
      file = Rack::Test::UploadedFile.new(
        Rails.root.join("e2e/test-image.tif"),
        "image/tiff"
      )
      params = { stamp: { original_file: file, extension: "docx" } }

      post stamps_path, params: params
      expect(response).to have_http_status(:unprocessable_entity)
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
