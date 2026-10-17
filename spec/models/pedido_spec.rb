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

  # Etapa 2.4 (decided 09/10/2026): a later change of the molde's price only reaches drafts.
  describe "#gravar_precos!" do
    it "writes each ordered number's price per pair from the molde into the grade" do
      molde = create(:molde)
      molde.faixas_de_preco.create!(tamanho_inicial: "18", tamanho_final: "30", preco_par: "9.5")
      pedido = create(:pedido)
      item = create(:item_pedido, pedido: pedido, arquivo: create(:arquivo, molde: molde, client: molde.client))
      %w[30 31].each { |numero| item.grades.create!(tamanho_nome: numero, quantidade: 1) }
      item.grades.create!(tamanho_nome: "29", quantidade: 0)
      pedido.gravar_precos!
      expect(item.grades.order(:tamanho_nome).pluck(:tamanho_nome, :preco_par)).to eq([ [ "29", nil ], [ "30", 9.5 ], [ "31", nil ] ])
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

  # Etapa 2.8 (5/5): sent to the factory, only the team changes it.
  it "is editable while sent only for the team, and confirmable until confirmed" do
    enviado = build(:pedido, status: "enviado")
    expect([ enviado.editavel?, enviado.editavel?(cliente_final: true), build(:pedido).editavel?(cliente_final: true) ]).to eq([ true, false, true ])
    expect(%w[rascunho enviado confirmado].map { |status| build(:pedido, status: status).confirmavel? }).to eq([ true, true, false ])
  end

  it "keeps a sent draft following its artes (.nao_confirmados)" do
    enviado = create(:pedido, status: "enviado")
    expect(Pedido.nao_confirmados).to include(enviado)
    expect(Pedido.nao_confirmados).not_to include(create(:pedido, status: "confirmado"))
  end

  it "refuses an unknown type, naming the expected ones" do
    pedido = build(:pedido, tipo: "bordado")
    expect(pedido).not_to be_valid
    expect(pedido.errors[:tipo].first).to include("bordado is not a pedido type; expected one of calcado, dtf, tecido")
  end

  # Etapa 2.6b1 (decided 13/10/2026): the type comes from the item.
  it "takes an item of its type, or any while empty; a DTF starts with the dono's extra rows" do
    create(:empresa).update!(fileiras_extras_dtf: 2)
    pedido = create(:pedido)
    expect(pedido.aceita_tipo?("dtf")).to be(true)
    pedido.update!(tipo: "dtf")
    expect(pedido.fileiras_extras).to eq(2)
    create(:item_pedido, pedido: pedido)
    expect([ pedido.aceita_tipo?("dtf"), pedido.aceita_tipo?("calcado") ]).to eq([ true, false ])
    expect(Pedido.tipo_para(Arte.new(tipo: "dtf"))).to eq("dtf")
    expect(Pedido.tipo_para(Arte.new(tipo: "calcado"))).to eq("calcado")
    expect(pedido.update(entrega: "dobrada")).to be(false)
  end

  # Etapa 2.7a (decided 16/10/2026): corridas and cores lisas go into a
  # tecido pedido, whose client is the pedido's like the DTF's.
  it "sends a corrida and a cor lisa to a tecido pedido, its client the pedido's" do
    expect(%w[corrida cor_lisa].map { |tipo| Pedido.tipo_para(Arte.new(tipo: tipo)) }).to eq(%w[tecido tecido])
    expect(Pedido.tipo_para(nil)).to eq("calcado")
    expect(%w[calcado dtf tecido].map { |tipo| build(:pedido, tipo: tipo).then { |p| [ p.tecido?, p.cliente_do_pedido? ] } }).to eq([ [ false, false ], [ false, true ], [ true, true ] ])
    expect(build(:pedido, tipo: "tecido", dono_tecido: "vizinho")).not_to be_valid
  end
end
