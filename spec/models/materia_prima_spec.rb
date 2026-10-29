require "rails_helper"

RSpec.describe MateriaPrima, type: :model do
  let(:grupo) { GrupoMaterial.find_or_create_by!(nome: "Oxford") }
  let(:cor) { CorMaterial.find_or_create_by!(nome: "Azul") }

  subject(:mp) do
    described_class.new(grupo_material: grupo, cor_material: cor, largura: "1.40", gramatura: "100g")
  end

  describe "validations" do
    it { should validate_presence_of(:largura) }

    # Dublagem 1/5: required by its group (a new group asks it, as before).
    it "requires the gramatura its group requires" do
      mp.gramatura = nil
      expect(mp).not_to be_valid
      expect(mp.errors.full_messages).to include("Gramatura é obrigatório no grupo Oxford")
    end
  end

  # Dublagem 1/5 (decided 27/10/2026): the group says what its materials ask.
  describe "the group's attributes" do
    let(:espuma) do
      GrupoMaterial.create!(nome: "Espuma", superficie: false, base: true, estampavel: "nao").tap do |g|
        g.update!(atributos: { "densidade" => true, "espessura_mm" => true, "fornecedor" => false })
      end
    end

    def nova_espuma(**atributos)
      described_class.new(grupo_material: espuma, cor_material: cor, largura: "1,40 m", **atributos)
    end

    it "refuses a new material without a required one, naming it and its group" do
      material = nova_espuma(espessura_mm: 3)
      expect(material).not_to be_valid
      expect(material.errors.full_messages).to eq([ "Densidade é obrigatório no grupo Espuma" ])
    end

    it "names it with its densidade and espessura, without a gramatura it isn't asked" do
      material = nova_espuma(densidade: " TC4 ", espessura_mm: 3, fornecedor: "Espumas Sul")
      material.save!
      expect([ material.nome_completo, material.gramatura ]).to eq([ "Espuma TC4 3 mm-Azul-1,40 m-Espumas Sul", "" ])
      expect(nova_espuma(densidade: "TC4", espessura_mm: 3.5).nome_completo).to eq("Espuma TC4 3,5 mm-Azul-1,40 m")
      expect(described_class.new(grupo_material: grupo, cor_material: cor, largura: "1", gramatura: "1g", micras: 35).nome_completo).to eq("Oxford 35 µm-Azul-1-1g")
    end

    it "tells two thicknesses apart, never the same one twice" do
      nova_espuma(densidade: "TC4", espessura_mm: 3).save!
      expect(nova_espuma(densidade: "TC4", espessura_mm: 5)).to be_valid
      expect(nova_espuma(densidade: "TC4", espessura_mm: 3)).not_to be_valid
    end

    it "marks, never refuses, a material registered before its group required more" do
      material = nova_espuma(densidade: "TC4", espessura_mm: 3).tap(&:save!)
      espuma.update!(atributos: espuma.atributos.merge("fornecedor" => true))
      expect(material.reload.atributos_faltando).to eq([ "fornecedor" ])
      expect(material.update(preco_metro: 18)).to be(true)
    end
  end

  describe ".estampaveis" do
    it "is the tecidos whose group prints" do
      mp.save!
      nao = GrupoMaterial.create!(nome: "Espuma", estampavel: "nao")
      espuma = described_class.create!(grupo_material: nao, cor_material: cor, largura: "1", gramatura: "1g")
      papel = described_class.create!(grupo_material: grupo, cor_material: cor, largura: "2", gramatura: "1g", tipo: "papel")
      expect(described_class.estampaveis.where(id: [ mp.id, espuma.id, papel.id ])).to eq([ mp ])
    end
  end

  # 28/10/2026: the insumos say the stage that uses them up; a fabric is
  # never chosen among them.
  describe "the insumos" do
    it "takes kraft and plástico de sucção, labeled with their stage" do
      expect(described_class::ROTULOS_DOS_TIPOS.values_at("kraft", "plastico_succao", "papel"))
        .to eq([ "Kraft (calandra)", "Plástico de sucção (corte)", "Papel (impressão)" ])
      mp.tipo = "plastico_succao"
      expect(mp).to be_valid
    end

    it "leaves them out of .tecidos and .estampaveis" do
      mp.save!
      kraft = described_class.create!(grupo_material: grupo, cor_material: cor, largura: "1.60", gramatura: "80g", tipo: "kraft")
      expect([ described_class.tecidos, described_class.estampaveis ].map { |escopo| escopo.where(id: [ mp.id, kraft.id ]) }).to eq([ [ mp ], [ mp ] ])
    end
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

  # Etapa 2.3: tecido, papel or filme (2.3d1: or filme_dtf), with a sale price per meter.
  it "is a tecido by default, takes papel or filme, naming a wrong type, and a non-negative price" do
    expect(mp.tipo).to eq("tecido")
    mp.tipo = "couro"
    mp.preco_metro = -1
    expect(mp).not_to be_valid
    expect(mp.errors.full_messages).to contain_exactly("Tipo couro is not a material type; expected one of tecido, papel, filme, filme_dtf, kraft, plastico_succao", "Preco metro must be greater than or equal to 0")
  end
end
