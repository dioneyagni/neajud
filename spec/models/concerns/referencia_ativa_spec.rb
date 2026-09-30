require "rails_helper"

RSpec.describe ReferenciaAtiva do
  let(:trashed_client) { create(:client, name: "Fagner").tap { |c| c.excluir!(changed_by: "10.0.0.1") } }

  it "refuses a new record pointing at a trashed one, naming it and the expected shape" do
    molde = build(:molde, client: trashed_client)
    expect(molde).not_to be_valid
    expect(molde.errors[:client]).to eq([ "\"Fagner\" (id #{trashed_client.id}) is in the trash; expected an active client" ])
  end

  it "refuses changing a reference to a trashed record" do
    arquivo = create(:arquivo)
    expect(arquivo.update(client: trashed_client)).to be false
  end

  it "keeps rows that already pointed at it valid and editable" do
    client = create(:client)
    molde = create(:molde, client: client)
    client.excluir!(changed_by: "10.0.0.1")

    expect(molde.reload.update(nome: "Renamed")).to be true
  end

  it "refuses linking a trashed arte to a pedido item" do
    arte = create(:arquivo).tap { |a| a.excluir!(changed_by: "10.0.0.1") }
    item = build(:item_pedido, arquivo: arte)
    expect(item).not_to be_valid
    expect(item.errors[:arquivo].first).to include("is in the trash")
  end
end
