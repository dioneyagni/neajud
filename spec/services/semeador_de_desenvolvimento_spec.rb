require "rails_helper"

RSpec.describe SemeadorDeDesenvolvimento do
  def semear = described_class.new(ambiente: "development").call

  it "creates the groups with their roles, printing and attributes" do
    semear

    espuma = GrupoMaterial.find_by!(nome: "Espuma")
    expect([ espuma.superficie, espuma.base, espuma.estampavel ]).to eq([ false, true, "nao" ])
    expect(espuma.atributos).to eq("densidade" => true, "espessura_mm" => true)
    expect(GrupoMaterial.find_by!(nome: "TNT")).to have_attributes(estampavel: "ressalvas", ressalva: "a estampa pode ficar menos nítida")
    expect(GrupoMaterial.find_by!(nome: "Oxford").atributos).to eq("gramatura" => true, "densidade" => false)
  end

  it "creates the materials with no stock, the ligantes as filme and the papel as papel" do
    semear

    expect(MateriaPrima.joins(:grupo_material).where(grupo_materiais: { nome: "Espuma" }).map(&:nome_completo))
      .to contain_exactly("Espuma TC4 3 mm-Branco-1.40 m", "Espuma TC4 5 mm-Branco-1.40 m")
    expect(MateriaPrima.find_by!(micras: 35).tipo).to eq("filme")
    expect(MateriaPrima.joins(:grupo_material).find_by!(grupo_materiais: { nome: "Papel" }).tipo).to eq("papel")
    expect(MovimentoEstoque.count).to eq(0)
  end

  it "adds nothing the second time" do
    semear
    contagens = [ GrupoMaterial.count, MateriaPrima.count, CorMaterial.count ]

    relatorio = semear

    expect([ GrupoMaterial.count, MateriaPrima.count, CorMaterial.count ]).to eq(contagens)
    expect(relatorio[:criados]).to be_empty
  end

  # The dev database holds real data: a group someone configured stays as they left it.
  it "never changes a group that already exists" do
    oxford = GrupoMaterial.create!(nome: "oxford", superficie: true, base: false, estampavel: "sim", atributos: { "gramatura" => false })

    relatorio = semear

    expect(oxford.reload).to have_attributes(base: false, atributos: { "gramatura" => false })
    expect(relatorio[:existentes]).to include("Oxford")
  end

  it "refuses any environment but development, naming it" do
    expect { described_class.new(ambiente: "production").call }
      .to raise_error(described_class::AmbienteErrado, /this is "production"/)
    expect(GrupoMaterial.count).to eq(0)
  end
end
