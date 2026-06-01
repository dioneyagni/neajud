require "rails_helper"

RSpec.describe ArquivoImageMetadata, type: :model do
  describe "associations" do
    it { should belong_to(:arquivo_version) }
  end
end
