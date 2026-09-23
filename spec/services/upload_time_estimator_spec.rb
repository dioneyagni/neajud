require "rails_helper"

RSpec.describe UploadTimeEstimator do
  let(:batch_started_at) { Time.zone.parse("2026-09-23 10:00:00") }

  it "returns 0 when nothing was uploaded before the batch" do
    expect(described_class.call(batch_started_at: batch_started_at, batch_size: 2)).to eq(0)
  end

  it "splits the gap since the last earlier upload evenly across the batch" do
    create(:arquivo, created_at: batch_started_at - 30.minutes)
    expect(described_class.call(batch_started_at: batch_started_at, batch_size: 3)).to eq(600)
  end

  it "treats a batch_size below 1 as 1 instead of dividing by zero" do
    create(:arquivo, created_at: batch_started_at - 10.minutes)
    expect(described_class.call(batch_started_at: batch_started_at, batch_size: 0)).to eq(600)
    expect(described_class.call(batch_started_at: batch_started_at, batch_size: -2)).to eq(600)
  end

  it "uses the most recent upload before the batch, ignoring ones after it started" do
    create(:arquivo, created_at: batch_started_at - 2.hours)
    create(:arquivo, created_at: batch_started_at - 10.minutes)
    create(:arquivo, created_at: batch_started_at + 5.seconds)
    expect(described_class.call(batch_started_at: batch_started_at, batch_size: 1)).to eq(600)
  end
end
