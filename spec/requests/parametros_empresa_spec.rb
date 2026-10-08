require "rails_helper"

# Etapa 2.2 (1/3, decided 07/10/2026): the dono sets the paper's width and the
# baixa's warning band.
RSpec.describe "Production parameters", type: :request do
  it "shows and saves the paper's width and the warning band" do
    get edit_parametros_path
    expect(response.body).to include('value="1600"')
    patch parametros_path, params: { empresa: { largura_papel_mm: "1800", tolerancia_abaixo_pct: "5", tolerancia_acima_pct: "30" } }
    expect(response).to redirect_to(edit_parametros_path)
    expect(Empresa.atual.attributes.values_at("largura_papel_mm", "tolerancia_abaixo_pct", "tolerancia_acima_pct")).to eq([ 1800, 5, 30 ])
  end

  it "refuses a width of zero, saying why" do
    patch parametros_path, params: { empresa: { largura_papel_mm: "0" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Largura papel mm must be greater than 0")
    expect(Empresa.atual.largura_papel_mm).to eq(1600)
  end
end
