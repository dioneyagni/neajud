require "rails_helper"

RSpec.describe Vinculo do
  it "accepts any combination of the fixed perfis" do
    expect(build(:vinculo, perfis: %w[atendimento designer])).to be_valid
  end

  it "refuses no perfil and unknown ones, listing what is expected" do
    expect(build(:vinculo, perfis: []).tap(&:validate).errors[:perfis].first).to include("at least one", "dono")
    expect(build(:vinculo, perfis: %w[dono chefe]).tap(&:validate).errors[:perfis].first).to include('["chefe"]', "cliente_final")
  end

  it "links a user to the empresa only once" do
    vinculo = create(:vinculo)
    expect(build(:vinculo, user: vinculo.user, empresa: vinculo.empresa)).not_to be_valid
  end
end
