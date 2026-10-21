require "rails_helper"

# Etapa 2.3d1 (decided 19/10/2026): whose fabric cascades cliente → molde →
# pedido, blank inherits; confirming writes each item's.
RSpec.describe DonoDoTecido do
  let(:client) { create(:client) }
  let(:molde) { create(:molde, client: client) }
  let(:pedido) { create(:pedido) }
  let(:item) do
    create(:item_pedido, pedido: pedido, arquivo: create(:arquivo, client: client)).tap { |i| i.arquivo.update_columns(molde_id: molde.id) }
  end

  def dono_e_nivel(origem) = [ origem.dono, origem.nivel ]

  it "is the client's when nothing is set, each level overriding the one above" do
    expect(dono_e_nivel(described_class.do_item(item))).to eq([ "cliente", :padrao ])
    client.update!(dono_tecido: "empresa")
    expect(dono_e_nivel(described_class.do_item(item.reload))).to eq([ "empresa", :cliente ])
    molde.update!(dono_tecido: "cliente")
    expect(dono_e_nivel(described_class.do_item(item.reload))).to eq([ "cliente", :molde ])
    pedido.update!(dono_tecido: "empresa")
    expect(dono_e_nivel(described_class.do_item(item.reload))).to eq([ "empresa", :pedido ])
  end

  it "keeps what confirming wrote, whatever the levels say later" do
    item
    client.update!(dono_tecido: "empresa")
    pedido.gravar_dono_do_tecido!
    client.update!(dono_tecido: "cliente")
    expect(dono_e_nivel(described_class.do_item(item.reload))).to eq([ "empresa", :item ])
    expect(dono_e_nivel(described_class.do_pedido(pedido.reload))).to eq([ "empresa", :item ])
  end

  # A tecido item has no molde: its file's molde (if any) never enters.
  it "skips the molde on a tecido pedido" do
    pedido.update!(tipo: "tecido", client: client)
    molde.update!(dono_tecido: "empresa")
    expect(dono_e_nivel(described_class.do_item(item))).to eq([ "cliente", :padrao ])
  end

  it "says what a blank pedido inherits, nil when its moldes differ" do
    item
    pedido.update!(dono_tecido: "empresa")
    expect(dono_e_nivel(described_class.herdado(pedido.reload))).to eq([ "cliente", :padrao ])
    outro = create(:molde, client: client, dono_tecido: "empresa")
    create(:item_pedido, pedido: pedido, arquivo: create(:arquivo, client: client)).arquivo.update_columns(molde_id: outro.id)
    expect(described_class.herdado(pedido.reload)).to be_nil
  end

  it "refuses an owner that isn't one, and takes blank as inherit" do
    molde.dono_tecido = "vizinho"
    expect(molde).not_to be_valid
    expect(molde.errors[:dono_tecido]).to eq([ "vizinho is not whose fabric; expected one of cliente, empresa or blank (inherits)" ])
    molde.update!(dono_tecido: "")
    expect(molde.reload.dono_tecido).to be_nil
  end

  it "groups a pedido's items by the owner of their fabric" do
    outro = create(:molde, client: client, dono_tecido: "empresa")
    da_empresa = create(:item_pedido, pedido: pedido, arquivo: create(:arquivo, client: client)).tap { |i| i.arquivo.update_columns(molde_id: outro.id) }
    expect(described_class.itens_por_dono(pedido.tap { item })).to eq("cliente" => [ item.id ], "empresa" => [ da_empresa.id ])
  end
end
