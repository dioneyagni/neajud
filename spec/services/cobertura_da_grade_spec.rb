require "rails_helper"

RSpec.describe CoberturaDaGrade do
  let(:molde) { create(:molde, tamanho_inicial: "24", tamanho_final: "28") }
  let(:corte) { create(:arquivo, :corte, tipo_grade: "par").tap { |c| c.moldes << molde } }

  def tamanhos(*listas)
    listas.each.with_index(1) do |numeros, posicao|
      create(:tamanho, arquivo: corte, position: posicao, nome: numeros.join("-"), numeros: numeros)
    end
  end

  it "says nothing when every size of the molde has exactly one tamanho" do
    tamanhos(%w[23 24], %w[25 26], %w[27 28])
    expect(described_class.avisos(corte)).to be_empty
  end

  it "names the missing and the repeated sizes" do
    tamanhos(%w[23 24], %w[24 25 26])
    expect(described_class.avisos(corte).map(&:descricao)).to eq([ "#{molde.nome}: faltam 27, 28; 24 está em dois tamanhos" ])
  end

  it "checks nothing until the corte has a grade type" do
    corte.update!(tipo_grade: nil)
    tamanhos(%w[23 24])
    expect(described_class.avisos(corte)).to be_empty
  end

  it "checks nothing for a molde without its stretch of the grade" do
    molde.update_columns(tamanho_inicial: nil, tamanho_final: nil)
    tamanhos(%w[23 24])
    expect(described_class.avisos(corte)).to be_empty
  end

  it "checks a molde the corte only reaches by the same-modelo fallback" do
    outro = create(:molde, tamanho_inicial: "24", tamanho_final: "24")
    tamanhos(%w[25 26])
    expect(described_class.aviso_do_molde(corte, outro).faltando).to eq(%w[24])
  end
end
