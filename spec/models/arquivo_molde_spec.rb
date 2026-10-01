require "rails_helper"

RSpec.describe ArquivoMolde, type: :model do
  describe "associations" do
    it { should belong_to(:arquivo) }
    it { should belong_to(:molde) }
  end

  describe "validations" do
    # Created, not built: the matcher saves without validations, and the
    # molde gets its number in a validation callback (Etapa 1.1, 4/5).
    subject { ArquivoMolde.new(arquivo: create(:arquivo), molde: create(:molde)) }
    it { should validate_uniqueness_of(:molde_id).scoped_to(:arquivo_id) }
  end
end
