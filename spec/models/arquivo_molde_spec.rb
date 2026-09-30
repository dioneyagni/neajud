require "rails_helper"

RSpec.describe ArquivoMolde, type: :model do
  describe "associations" do
    it { should belong_to(:arquivo) }
    it { should belong_to(:molde) }
  end

  describe "validations" do
    subject { ArquivoMolde.new(arquivo: build(:arquivo), molde: build(:molde)) }
    it { should validate_uniqueness_of(:molde_id).scoped_to(:arquivo_id) }
  end
end
