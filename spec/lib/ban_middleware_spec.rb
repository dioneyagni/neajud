require "rails_helper"
require "rack/test"

RSpec.describe BanMiddleware do
  let(:inner_app) { ->(env) { [ 200, { "Content-Type" => "text/html" }, [ "OK" ] ] } }
  let(:app) { described_class.new(inner_app) }

  def make_request(ip: "127.0.0.1", path: "/")
    env = Rack::MockRequest.env_for(path, "REMOTE_ADDR" => ip)
    Rack::MockResponse.new(*app.call(env))
  end

  context "when no ban exists" do
    it "passes the request through" do
      response = make_request(ip: "10.0.0.1")
      expect(response.status).to eq(200)
      expect(response.body).to eq("OK")
    end
  end

  context "when an active ban exists for the IP" do
    before { create(:ban, ip_address: "192.168.1.100", expires_at: 1.hour.from_now) }

    it "returns 403 with JSON error" do
      response = make_request(ip: "192.168.1.100")
      expect(response.status).to eq(403)
      json = JSON.parse(response.body)
      expect(json["error"]).to eq("Your IP has been banned.")
    end
  end

  context "when a ban exists but is expired" do
    before { create(:ban, ip_address: "192.168.1.100", expires_at: 1.hour.ago) }

    it "passes the request through" do
      response = make_request(ip: "192.168.1.100")
      expect(response.status).to eq(200)
    end
  end

  context "when ban has no expiration (permanent)" do
    before { create(:ban, ip_address: "10.10.10.10", expires_at: nil) }

    it "returns 403" do
      response = make_request(ip: "10.10.10.10")
      expect(response.status).to eq(403)
    end
  end

  context "when a different IP is banned" do
    before { create(:ban, ip_address: "192.168.1.100") }

    it "passes the request through for other IPs" do
      response = make_request(ip: "192.168.1.200")
      expect(response.status).to eq(200)
    end
  end

  context "when Ban.active.exists? raises" do
    before do
      allow(Ban).to receive_message_chain(:active, :exists?).and_raise(ActiveRecord::ConnectionNotEstablished, "no connection")
    end

    it "logs error and passes the request through" do
      expect(Rails.logger).to receive(:error).with(/BanMiddleware/)
      response = make_request(ip: "1.2.3.4")
      expect(response.status).to eq(200)
    end
  end
end
