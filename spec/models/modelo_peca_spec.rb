require "rails_helper"

RSpec.describe ModeloPeca, type: :model do
  describe "associations" do
    it { should belong_to(:modelo) }
    it { should belong_to(:peca) }
  end
end
