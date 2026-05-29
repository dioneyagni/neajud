require "rails_helper"

RSpec.describe ArquivoTimeLog, type: :model do
  subject(:log) { build(:arquivo_time_log) }

  describe "validations" do
    it { should validate_presence_of(:previous_seconds) }
    it { should validate_presence_of(:new_seconds) }
  end

  describe "associations" do
    it { should belong_to(:arquivo) }
  end

  describe "callbacks" do
    it "generates uuid before create" do
      arquivo = create(:arquivo)
      log = create(:arquivo_time_log, arquivo: arquivo)
      expect(log.uuid).to be_present
      expect(log.uuid).to match(/\A[0-9a-f-]{36}\z/)
    end
  end
end
