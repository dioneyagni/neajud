require "rails_helper"

RSpec.describe MoldePeca, type: :model do
  describe "associations" do
    it { should belong_to(:molde) }
    it { should belong_to(:peca) }
  end
end
