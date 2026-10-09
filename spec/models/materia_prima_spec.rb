require "rails_helper"

RSpec.describe MateriaPrima, type: :model do
  let(:grupo) { GrupoMaterial.find_or_create_by!(nome: "Oxford") }
  let(:cor) { CorMaterial.find_or_create_by!(nome: "Azul") }

  subject(:mp) do
    described_class.new(grupo_material: grupo, cor_material: cor, largura: "1.40", gramatura: "100g")
  end

  describe "validations" do
    it { should validate_presence_of(:largura) }
    it { should validate_presence_of(:gramatura) }
  end

  describe "associations" do
    it { should belong_to(:grupo_material) }
    it { should belong_to(:cor_material) }
    it { should have_many(:movimento_estoques).dependent(:restrict_with_error) }
  end

  describe "#nome_completo" do
    it "returns formatted name with group, color, width and weight" do
      expect(mp.nome_completo).to eq("Oxford-Azul-1.40-100g")
    end
  end

  describe "#saldo" do
    it "returns zero when no movements exist" do
      mp.save!
      expect(mp.saldo).to eq(0.0)
    end

    it "calculates entrada minus saida" do
      mp.save!
      mp.movimento_estoques.create!(client: create(:client), tipo: "entrada", quantidade: 10)
      mp.movimento_estoques.create!(client: create(:client), tipo: "saida", quantidade: 3)
      expect(mp.saldo).to eq(7.0)
    end

    it "accepts an optional cache" do
      cache = { mp.id => 15.0 }
      expect(mp.saldo(cache)).to eq(15.0)
    end
  end

  # Etapa 2.2 (1/3): the roll's width for each size's fit.
  describe "#largura_mm" do
    it "reads the typed width with or without unit" do
      larguras = [ "1.25 m", "1,40", "140 cm", "1400 mm", "1.6", "abc" ].map { |l| described_class.new(largura: l).largura_mm }
      expect(larguras).to eq([ 1250, 1400, 1400, 1400, 1600, nil ])
    end
  end

  it "queues every size's meters per piece on a new width" do
    ActiveJob::Base.queue_adapter = :test
    corte = create(:arquivo, :corte)
    tamanho = create(:tamanho, arquivo: corte)
    expect { mp.save! }.to have_enqueued_job(MetrosPorPecaJob).with([ tamanho.id ], [ 1400 ])
  ensure
    ActiveJob::Base.queue_adapter = :inline
  end

  # Etapa 2.3: tecido, papel or filme, with a sale price per meter.
  it "is a tecido by default, takes papel or filme, naming a wrong type, and a non-negative price" do
    expect(mp.tipo).to eq("tecido")
    mp.tipo = "couro"
    mp.preco_metro = -1
    expect(mp).not_to be_valid
    expect(mp.errors.full_messages).to contain_exactly("Tipo couro is not a material type; expected tecido, papel or filme", "Preco metro must be greater than or equal to 0")
  end
end
