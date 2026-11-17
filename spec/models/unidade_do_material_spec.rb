require "rails_helper"

# Dublagem 5b2a (decided 12/11/2026, Q1a): the group says what its materials
# are counted in — meters, or kg for the cola, whose materials have no width
# and say their consumption in g/m² (Q2a).
RSpec.describe "Unidade do material" do
  let(:cor) { CorMaterial.find_or_create_by!(nome: "Branco") }
  let(:cola) { GrupoMaterial.create!(nome: "Cola", superficie: false, unidade: "kg", atributos: { "consumo_g_m2" => true }) }

  def cola_pu(**campos) = MateriaPrima.new(grupo_material: cola, cor_material: cor, tipo: "filme", consumo_g_m2: 120, **campos)

  it "counts a group in meters unless it says kg, and refuses another unit naming it" do
    expect(GrupoMaterial.create!(nome: "Oxford").unidade).to eq("m")
    grupo = GrupoMaterial.new(nome: "Tinta", unidade: "litro")
    expect(grupo).not_to be_valid
    expect(grupo.errors[:unidade]).to eq([ "litro is not a unit; expected one of m, kg" ])
  end

  it "keeps the unit once the group has a material, saying how many" do
    expect(cola.unidade_fixa?).to be(false)
    cola_pu.save!
    cola.unidade = "m"
    expect(cola).not_to be_valid
    expect(cola.errors[:unidade]).to eq([ "não muda: o grupo tem 1 material contado em kg" ])
    expect(cola.reload.unidade_fixa?).to be(true)
  end

  it "takes a kg material without a width, named by its consumption" do
    material = cola_pu
    expect(material).to be_valid
    material.save!
    expect([ material.unidade, material.em_kg?, material.largura, material.nome_completo ]).to eq([ "kg", true, "", "Cola-Branco-120 g/m²" ])
  end

  it "still asks a width in meters, and the consumption when the group requires it" do
    oxford = MateriaPrima.new(grupo_material: GrupoMaterial.create!(nome: "Oxford"), cor_material: cor, gramatura: "100g")
    expect(oxford).not_to be_valid
    expect(oxford.errors[:largura]).to be_present
    expect(cola_pu(consumo_g_m2: nil)).not_to be_valid
  end

  it "tells two colas apart by their consumption" do
    cola_pu.save!
    expect { cola_pu(consumo_g_m2: 150).save! }.to change(MateriaPrima, :count).by(1)
    expect(cola_pu).not_to be_valid
  end

  it "never counts a tecido in kg, naming the type and the group" do
    material = cola_pu(tipo: "tecido")
    expect(material).not_to be_valid
    expect(material.errors[:tipo]).to eq([ "tecido can't be counted in kg (group Cola); expected a ligante or an insumo" ])
  end
end
