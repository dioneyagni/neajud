require "rails_helper"

RSpec.describe AtribuiPorUuid do
  let(:client) { create(:client) }

  it "links the record whose uuid is given and reads it back" do
    modelo = Modelo.new(nome: "Fuel", client_uuid: client.uuid)
    expect(modelo.client).to eq(client)
    expect(modelo.client_uuid).to eq(client.uuid)
  end

  it "unlinks on a blank uuid" do
    arquivo = create(:arquivo, client: client)
    arquivo.update!(client_uuid: "")
    expect(arquivo.reload.client).to be_nil
  end

  # The reason for *_uuid instead of a uuid in *_id: Rails would cast
  # "8f3a…" to the integer 8 and link another record without a word.
  it "raises instead of linking nothing (or the wrong record) on an unknown uuid or an integer id" do
    expect { Modelo.new(client_uuid: "8f3a-nao-existe") }.to raise_error(ActiveRecord::RecordNotFound)
    expect { Modelo.new(client_uuid: client.id.to_s) }.to raise_error(ActiveRecord::RecordNotFound)
  end

  it "refuses a declaration for an association the model doesn't have" do
    expect { Client.atribui_por_uuid(:molde) }.to raise_error(ArgumentError, /Client has no belongs_to :molde/)
  end
end
