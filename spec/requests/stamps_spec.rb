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
    let(:valid_params) do
      {
        stamp: {
          filename: "test",
          extension: "tif",
          mime_type: "image/tiff"
        }
      }
    end

    it "creates a stamp" do
      expect { post stamps_path, params: valid_params }.to change(Stamp, :count).by(1)
    end

    it "redirects to gallery" do
      post stamps_path, params: valid_params
      expect(response).to redirect_to(stamps_path)
    end

    it "enqueues processing job" do
      expect { post stamps_path, params: valid_params }.to have_enqueued_job(StampProcessingJob)
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