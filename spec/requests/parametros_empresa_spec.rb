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

  # Etapa 2.3: the default paper, a material of type papel.
  it "chooses the default paper among the papers, ignoring anything else" do
    papel = MateriaPrima.create!(grupo_material: GrupoMaterial.create!(nome: "Papel"), cor_material: CorMaterial.create!(nome: "Branco"), largura: "1,10 m", gramatura: "40g", tipo: "papel")
    tecido = MateriaPrima.create!(grupo_material: GrupoMaterial.create!(nome: "Oxford"), cor_material: CorMaterial.create!(nome: "Preto"), largura: "1,40 m", gramatura: "80g")
    get edit_parametros_path
    expect(Nokogiri::HTML(response.body).css("#empresa_papel_padrao_uuid option").map(&:text)).to eq([ "None — use the width below", "Papel-Branco-1,10 m-40g (1100 mm)" ])
    patch parametros_path, params: { empresa: { papel_padrao_uuid: papel.uuid } }
    expect([ Empresa.atual.papel_padrao, Empresa.atual.largura_papel_efetiva_mm ]).to eq([ papel, 1100 ])
    patch parametros_path, params: { empresa: { papel_padrao_uuid: tecido.uuid } }
    expect(Empresa.atual.reload.papel_padrao).to be_nil
  end

  # Etapa 2.4: the cost per pair's two parameters, typed with a comma.
  it "saves the printing cost per meter and the cutting cost per piece; blank leaves them unset" do
    patch parametros_path, params: { empresa: { custo_impressao_metro: "4,50", custo_corte_peca: "0,075" } }
    expect([ Empresa.atual.custo_impressao_metro, Empresa.atual.custo_corte_peca ]).to eq([ 4.5, 0.075 ])
    patch parametros_path, params: { empresa: { custo_corte_peca: "" } }
    expect(Empresa.atual.reload.custos_definidos?).to be(false)
  end
end
