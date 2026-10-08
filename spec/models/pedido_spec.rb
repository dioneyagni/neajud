require "rails_helper"

RSpec.describe Pedido, type: :model do
  subject(:pedido) { build(:pedido) }

  describe "validations" do
    it { should validate_presence_of(:status) }
    it { should validate_inclusion_of(:status).in_array(%w[rascunho confirmado em_producao entregue cancelado]).with_message(/is not a pedido status/) }

    it "validates uuid uniqueness" do
      pedido.save!
      dup = build(:pedido, uuid: pedido.uuid)
      expect(dup).not_to be_valid
      expect(dup.errors[:uuid]).to include(/already been taken/i)
    end
  end

  describe "associations" do
    it { should belong_to(:client).optional }
    it { should have_many(:itens_pedido).dependent(:destroy) }
  end

  describe "callbacks" do
    it "generates uuid before create" do
      pedido.save!
      expect(pedido.uuid).to be_present
      expect(pedido.uuid).to match(/\A[0-9a-f-]{36}\z/)
    end
  end

  describe "#to_param" do
    it "returns uuid" do
      pedido.save!
      expect(pedido.to_param).to eq(pedido.uuid)
    end
  end

  describe "#total_itens" do
    it "sums grade quantities" do
      pedido.save!
      item = create(:item_pedido, pedido: pedido)
      create(:item_pedido_grade, item_pedido: item, quantidade: 3)
      create(:item_pedido_grade, item_pedido: item, tamanho_nome: "Tam X", quantidade: 2)
      expect(pedido.total_itens).to eq(5)
    end

    it "returns 0 when no grades exist" do
      pedido.save!
      create(:item_pedido, pedido: pedido)
      expect(pedido.total_itens).to eq(0)
    end
  end

  describe "scopes" do
    it ".rascunhos includes rascunho pedidos" do
      p = create(:pedido, status: "rascunho")
      expect(Pedido.rascunhos).to include(p)
    end

    it ".rascunhos excludes confirmado pedidos" do
      p = create(:pedido, status: "confirmado")
      expect(Pedido.rascunhos).not_to include(p)
    end

    it ".confirmados includes confirmado pedidos" do
      p = create(:pedido, status: "confirmado")
      expect(Pedido.confirmados).to include(p)
    end
  end

  describe "#bloqueios_confirmacao" do
    it "delegates to PedidoBloqueiosService" do
      pedido = create(:pedido)
      expect(PedidoBloqueiosService).to receive(:call).with(pedido).and_return([])
      expect(pedido.bloqueios_confirmacao).to eq([])
    end
  end

  describe "#pecas_para_produzir" do
    it "delegates to ProducaoPedidoService" do
      pedido = create(:pedido)
      expect(ProducaoPedidoService).to receive(:call).with(pedido).and_return([])
      expect(pedido.pecas_para_produzir).to eq([])
    end
  end

  # Regression (01/10/2026, ed6a2aba): a draft created for an arte without
  # client stayed without one after the arte got its client.
  describe "a draft without client and its artes' client" do
    let(:mks) { create(:client, name: "MKS") }
    let(:pedido) { create(:pedido, client: nil) }

    def item_com(client)
      create(:item_pedido, pedido: pedido, arquivo: create(:arquivo, category: "artes", client: client))
    end

    it "adopts the client once its only arte gets one" do
      arte = item_com(nil).arquivo
      expect(pedido.reload.client).to be_nil
      arte.update!(client: mks)
      expect(pedido.reload.client).to eq(mks)
    end

    it "waits while some arte has no client or the artes have different clients" do
      item_com(mks)
      sem = item_com(nil).arquivo
      pedido.adotar_cliente_das_artes!
      expect(pedido.reload.client).to be_nil
      sem.update!(client: create(:client, name: "GMS"))
      expect(pedido.reload.client).to be_nil
      expect(pedido.clientes_das_artes.map(&:name)).to eq(%w[GMS MKS])
    end

    it "never changes a confirmed pedido or one that already has a client" do
      confirmado = create(:pedido, client: nil, status: "confirmado")
      arte = create(:arquivo, category: "artes", client: nil)
      create(:item_pedido, pedido: confirmado, arquivo: arte)
      arte.update!(client: mks)
      expect(confirmado.reload.client).to be_nil
    end
  end

  it "is not editable with the old grade (Etapa 1.2, 3/3), even restored" do
    expect([ build(:pedido).editavel?, build(:pedido, grade_antiga: true).editavel? ]).to eq([ true, false ])
  end

  it "refuses an unknown type, naming the expected ones" do
    pedido = build(:pedido, tipo: "dtf")
    expect(pedido).not_to be_valid
    expect(pedido.errors[:tipo].first).to include("dtf is not a pedido type; expected one of calcado")
  end
end
