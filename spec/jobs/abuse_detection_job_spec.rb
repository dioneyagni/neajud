require "rails_helper"

RSpec.describe AbuseDetectionJob, type: :job do
  describe "#perform" do
    let(:ip) { "192.168.1.1" }

    it "returns early for small files" do
      expect(Rails.cache).not_to receive(:increment)
      AbuseDetectionJob.perform_now(ip_address: ip, file_size: 1.megabyte)
    end

    it "increments cache counter for large files" do
      expect(Rails.cache).to receive(:increment)
        .with("abuse:#{ip}", 1, expires_in: AbuseDetectionJob::BAN_DURATION)
        .and_return(1)
      AbuseDetectionJob.perform_now(ip_address: ip, file_size: AbuseDetectionJob::LARGE_FILE_THRESHOLD)
    end

    it "creates a ban when count reaches threshold" do
      allow(Rails.cache).to receive(:increment)
        .with("abuse:#{ip}", 1, expires_in: AbuseDetectionJob::BAN_DURATION)
        .and_return(AbuseDetectionJob::MAX_LARGE_FILES)

      expect(Rails.cache).to receive(:delete).with("abuse:#{ip}")
      expect(Rails.logger).to receive(:warn).with("[AbuseDetection] Banned IP #{ip} for abuse")

      expect {
        AbuseDetectionJob.perform_now(ip_address: ip, file_size: AbuseDetectionJob::LARGE_FILE_THRESHOLD)
      }.to change(Ban, :count).by(1)

      ban = Ban.last
      expect(ban.ip_address).to eq(ip)
      expect(ban.reason).to include("500MB")
      expect(ban.expires_at).to be > Time.current
    end

    it "increments from 1 after cache is reset" do
      allow(Rails.cache).to receive(:increment)
        .with("abuse:#{ip}", 1, expires_in: AbuseDetectionJob::BAN_DURATION)
        .and_return(1)

      expect {
        AbuseDetectionJob.perform_now(ip_address: ip, file_size: AbuseDetectionJob::LARGE_FILE_THRESHOLD)
      }.not_to change(Ban, :count)
    end

    it "handles different IP addresses independently" do
      cache = double
      allow(Rails).to receive(:cache).and_return(cache)

      expect(cache).to receive(:increment).with("abuse:10.0.0.1", 1, expires_in: AbuseDetectionJob::BAN_DURATION).and_return(1)
      expect(cache).to receive(:increment).with("abuse:10.0.0.2", 1, expires_in: AbuseDetectionJob::BAN_DURATION).and_return(1)

      AbuseDetectionJob.perform_now(ip_address: "10.0.0.1", file_size: AbuseDetectionJob::LARGE_FILE_THRESHOLD)
      AbuseDetectionJob.perform_now(ip_address: "10.0.0.2", file_size: AbuseDetectionJob::LARGE_FILE_THRESHOLD)
    end
  end
end
