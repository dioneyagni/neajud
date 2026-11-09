require "rails_helper"
require_relative "../support/construcoes"

RSpec.describe RedeDeDublagens do
  before { importar_rede_de_dublagens }

  it "reads the network from the database, the initial one imported" do
    expect(described_class.ligacoes.size).to eq(LigacaoDublagem.count)
    expect(described_class.situacoes).to eq("vai_frequencia" => "Vai frequência", "tecido_molha" => "Tecido molha")
  end

  # Decision 2 (29/10/2026): the pair has no order.
  it "finds a ligação in either order, and nil for a pair that doesn't dub" do
    expect(described_class.ligacao("Lona", "Oxford")).to have_attributes(dubla: "antes")
    expect(described_class.ligacao("oxford", "LONA").ligantes.map(&:descricao)).to eq([ "Filme 35 µm ou mais" ])
    expect(described_class.ligacao("Lona", "EVA")).to be_nil
  end

  it "lists a group's ligações and the other group of each" do
    expect(described_class.ligacoes_de("Espuma").map { |l| l.outro("Espuma") }).to contain_exactly("Oxford", "Helanca")
  end

  # Decision 3: a situação replaces the usual ligantes; one not listed keeps them.
  it "gives a situação's ligantes, else the usual ones" do
    oxford = described_class.ligacao("Oxford", "Oxford")
    expect(oxford.ligantes_na("vai_frequencia").map(&:descricao)).to eq([ "Filme 35 µm" ])
    expect(oxford.ligantes_na(nil).map(&:descricao)).to eq([ "Filme 25 ou 35 µm" ])
    expect(described_class.ligacao("Oxford", "EVA").ligantes_na("vai_frequencia").map(&:descricao)).to eq([ "Filme 25 µm" ])
  end

  # Dublagem 3/5: a registered material is a ligante of the network.
  it "tells whether a material is a ligante: its group, micras in the list or at least the minimum" do
    grupo = GrupoMaterial.find_by!(nome: "Filme")
    filme = ->(micras) { MateriaPrima.new(grupo_material: grupo, micras: micras) }
    lista, minimo, qualquer = described_class::Ligante.new(grupo: "Filme", micras: [ 25, 35 ]), described_class::Ligante.new(grupo: "filme", minimo: 35), described_class::Ligante.new(grupo: "Filme PU")

    expect([ lista.serve?(filme.(25)), lista.serve?(filme.(30)) ]).to eq([ true, false ])
    expect([ minimo.serve?(filme.(50)), minimo.serve?(filme.(25)) ]).to eq([ true, false ])
    expect(qualquer.serve?(filme.(25))).to be(false)
  end

  it "prefers the ligação of the lado asked, else the one for any side" do
    oxford, lona = GrupoMaterial.find_by!(nome: "Oxford"), GrupoMaterial.find_by!(nome: "Lona")
    LigacaoDublagem.create!(grupo_a: oxford, grupo_b: lona, lado: "avesso", dubla: "depois")
    expect([ described_class.ligacao("Oxford", "Lona", lado: "avesso").dubla, described_class.ligacao("Oxford", "Lona", lado: "trama").dubla ]).to eq(%w[depois antes])
  end

  # Read once per request or job (Current), forgotten when the network changes.
  it "sees a change to the network on the next read" do
    expect(described_class.ligacao("Lona", "EVA")).to be_nil
    LigacaoDublagem.create!(grupo_a: GrupoMaterial.find_by!(nome: "Lona"), grupo_b: GrupoMaterial.find_by!(nome: "EVA"), dubla: "depois")
    expect(described_class.ligacao("EVA", "Lona").dubla).to eq("depois")
  end

  it "reads only the scopes it is given" do
    rede = described_class.new(ligacoes: LigacaoDublagem.where(grupo_a: GrupoMaterial.where(nome: "Espuma")), situacoes: SituacaoDublagem.where(chave: "tecido_molha"))
    expect(rede.ligacoes.map(&:par)).to eq([ %w[Espuma Helanca] ])
    expect(rede.situacoes.keys).to eq([ "tecido_molha" ])
  end

  # Since 1/2 every group is registered: what is left to warn is the roles.
  describe ".avisos" do
    it "warns when neither may go underneath, or a group is neither superfície nor base" do
      expect(described_class.avisos(described_class.ligacao("Oxford", "Lona"))).to be_empty

      GrupoMaterial.where(nome: %w[Oxford Lona]).find_each { |grupo| grupo.update!(base: false) }
      described_class.esquecer
      expect(described_class.avisos(described_class.ligacao("Oxford", "Lona"))).to contain_exactly("Lona não é superfície nem base", "nenhum é base: Oxford e Lona")
    end
  end
end
