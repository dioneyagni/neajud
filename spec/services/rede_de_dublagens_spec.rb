require "rails_helper"

RSpec.describe RedeDeDublagens do
  def ligacao(**campos)
    { "par" => %w[Oxford Lona], "ligantes" => [ { "grupo" => "Filme", "micras" => { "min" => 35 } } ], "dubla" => "antes" }.merge(campos.transform_keys(&:to_s))
  end

  def rede(*ligacoes) = { "situacoes" => { "tecido_molha" => "Tecido molha" }, "ligacoes" => ligacoes }

  def ler(*ligacoes) = described_class.ler(rede(*ligacoes))

  it "reads config/dublagens.yml" do
    expect(described_class.ligacoes).to be_present
    expect(described_class.situacoes).to include("vai_frequencia" => "Vai frequência")
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

  it "prefers the ligação of the lado asked, else the one for any side" do
    lida = ler(ligacao, ligacao("lado" => "avesso", "dubla" => "depois"))
    allow(described_class).to receive(:rede).and_return(lida)
    expect([ described_class.ligacao("Oxford", "Lona", lado: "avesso").dubla, described_class.ligacao("Oxford", "Lona", lado: "trama").dubla ]).to eq(%w[depois antes])
  end

  describe "checking the file" do
    {
      "an unknown field" => [ { "cor" => "x" }, /unknown field "cor"/ ],
      "a pair of one" => [ { "par" => [ "Oxford" ] }, /par \["Oxford"\] must be two group names/ ],
      "a wrong dubla" => [ { "dubla" => "durante" }, /dubla "durante" is not one of antes, depois/ ],
      "a wrong lado" => [ { "lado" => "costas" }, /lado "costas" is not one of trama, avesso/ ],
      "no ligante" => [ { "ligantes" => [] }, /ligantes must list at least one ligante/ ],
      "micras not integer" => [ { "ligantes" => [ { "grupo" => "Filme", "micras" => [ "25" ] } ] }, /micras \["25"\] must be a list of positive integers/ ],
      "a situação not declared" => [ { "situacoes" => { "chove" => [ { "grupo" => "Cola" } ] } }, /situação "chove" is not one of tecido_molha/ ],
      "a wrong a_confirmar" => [ { "a_confirmar" => [ "preco" ] }, /a_confirmar "preco" is not one of/ ]
    }.each do |caso, (campos, mensagem)|
      it "refuses #{caso}, naming the ligação and the value" do
        expect { ler(ligacao(**campos.transform_keys(&:to_sym))) }.to raise_error(described_class::Invalida, /ligacao 1 .*#{mensagem.source}/)
      end
    end

    it "refuses the same pair twice, in any order" do
      expect { ler(ligacao, ligacao("par" => %w[Lona Oxford])) }.to raise_error(described_class::Invalida, /pair Lona–Oxford appears 2 times/)
    end
  end

  # Decision 1: a group not registered is a warning, never an error.
  describe ".avisos" do
    def grupo(nome, superficie: true, base: false) = GrupoMaterial.create!(nome: nome, superficie: superficie, base: base)

    it "names the groups and ligantes not registered" do
      grupos = [ grupo("Oxford") ]
      expect(described_class.avisos(described_class.ligacao("Oxford", "Lona"), grupos)).to contain_exactly("Lona — não cadastrado", "Filme — não cadastrado", "Filme PU — não cadastrado")
    end

    it "warns when neither may go underneath, or a group is neither superfície nor base" do
      grupos = [ grupo("Oxford"), grupo("Lona", superficie: false), grupo("Filme", superficie: false), grupo("Filme PU", superficie: false) ]
      expect(described_class.avisos(described_class.ligacao("Oxford", "Lona"), grupos))
        .to contain_exactly("Lona não é superfície nem base", "nenhum é base: Oxford e Lona")
      grupos[1].update!(base: true)
      expect(described_class.avisos(described_class.ligacao("Oxford", "Lona"), grupos)).to be_empty
    end
  end
end
