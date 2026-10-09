require "rails_helper"

# Etapa 2.4 (decided 09/10/2026): the molde's price per pair by band of its
# produto's grade (18–46 in the factory).
RSpec.describe FaixaDePreco do
  let(:molde) { create(:molde) }

  def faixa(inicial, final, preco = 10) = molde.faixas_de_preco.build(tamanho_inicial: inicial, tamanho_final: final, preco_par: preco)

  it "covers a stretch of the produto's grade, also outside the molde's own sizes" do
    expect(faixa("23", "26").numeros).to eq(%w[23 24 25 26])
    expect([ faixa("23", "26").rotulo, faixa("27", "27").rotulo ]).to eq([ "23–26", "27" ])
  end

  it "refuses ends that aren't a stretch of the grade, saying the grade" do
    nova = faixa("30", "25")
    expect(nova).not_to be_valid
    expect(nova.errors[:tamanho_final]).to eq([ "\"30\"–\"25\" is not a stretch of 18–46 (both ends in the grade, first ≤ last)" ])
  end

  it "refuses a band that overlaps another: each number has one price" do
    faixa("23", "30").save!
    nova = faixa("30", "34")
    expect(nova).not_to be_valid
    expect(nova.errors[:base]).to eq([ "30–34 overlaps the band 23–30 of #{molde.nome}: each number has one price" ])
  end

  it "refuses a negative price" do
    expect(faixa("23", "30", -1)).not_to be_valid
  end

  it "gives the molde's price of a number, nil where no band covers it" do
    faixa("23", "30", "9.5").save!
    faixa("31", "36", 11).save!
    expect([ molde.preco_do_par("27"), molde.preco_do_par("31"), molde.preco_do_par("40") ]).to eq([ 9.5, 11, nil ])
  end
end
