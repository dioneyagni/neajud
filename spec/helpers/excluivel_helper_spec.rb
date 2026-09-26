require "rails_helper"

RSpec.describe ExcluivelHelper, type: :helper do
  it "renders the badge with the deletion date for a trashed record" do
    client = create(:client, deleted_at: Time.zone.local(2026, 9, 20, 10))
    expect(helper.selo_excluido(client)).to include("excluído em 20/09/2026", 'class="badge-excluido"')
  end

  it "renders nothing for active records and nil" do
    expect(helper.selo_excluido(create(:client))).to be_nil
    expect(helper.selo_excluido(nil)).to be_nil
  end
end
