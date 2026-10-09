require "rails_helper"

# Etapa 2.4 (decided 09/10/2026): the molde's price per pair by band of the
# grade, on the molde page (the signed-in user is a dono: ver_valores).
RSpec.describe "Faixas de preço do molde", type: :request do
  let(:molde) { create(:molde, tamanho_inicial: "28", tamanho_final: "34") }

  def criar(inicial, final, preco)
    post molde_faixas_path(molde), params: { faixa: { tamanho_inicial: inicial, tamanho_final: final, preco_par: preco } }
  end

  it "adds a band with a comma price, back on the molde's prices" do
    criar("28", "30", "9,50")
    expect(response).to redirect_to(molde_path(molde, anchor: "molde-precos"))
    expect(flash[:notice]).to eq("Price 28–30 saved.")
    expect(molde.preco_do_par("29")).to eq(9.5)
  end

  it "takes a band of one number when the end is blank" do
    criar("31", "", "11")
    expect(molde.faixas_de_preco.sole.rotulo).to eq("31")
  end

  it "says why a band is refused, saving nothing" do
    criar("28", "30", "9")
    criar("30", "32", "10")
    expect(flash[:alert]).to eq("30–32 overlaps the band 28–30 of #{molde.nome}: each number has one price")
    expect(molde.faixas_de_preco.count).to eq(1)
  end

  it "edits and removes a band by its uuid" do
    criar("28", "30", "9")
    faixa = molde.faixas_de_preco.sole
    patch molde_faixa_path(molde, faixa), params: { faixa: { tamanho_inicial: "28", tamanho_final: "34", preco_par: "12" } }
    expect([ faixa.reload.rotulo, faixa.preco_par ]).to eq([ "28–34", 12 ])
    delete molde_faixa_path(molde, faixa)
    expect(molde.faixas_de_preco).to be_empty
  end

  it "shows the bands on the molde page and the molde's sizes still without price" do
    criar("28", "30", "9")
    get molde_path(molde)
    html = Nokogiri::HTML(response.body)
    expect(html.at_css(".molde-preco[data-faixa='28–30'] input[name='faixa[preco_par]']")["value"]).to eq("9,00")
    expect(html.at_css(".molde-precos-faltando").text).to include("31, 32, 33, 34")
  end
end
