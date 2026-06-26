require "rails_helper"

RSpec.describe ArquivoModelo, type: :model do
  describe "associations" do
    it { should belong_to(:arquivo) }
    it { should belong_to(:modelo) }
  end

  describe "validations" do
    subject { ArquivoModelo.new(arquivo: build(:arquivo), modelo: build(:modelo)) }
    it { should validate_uniqueness_of(:modelo_id).scoped_to(:arquivo_id) }
  end
end
