require "rails_helper"

# Dublagem 5b2a (decided 12/11/2026, Q1a): a group counted in kg — the
# cola — on the group page, the stock entry and the stock pages.
RSpec.describe "Cola em kg", type: :request do
  let(:cor) { CorMaterial.find_or_create_by!(nome: "Branco") }
  let(:cola) { GrupoMaterial.create!(nome: "Cola", superficie: false, unidade: "kg", atributos: { "consumo_g_m2" => true }) }

  def entrada(quantidade: "1,5", **campos)
    post movimentos_path, params: { movimento_estoque: { da_empresa: "true", tipo: "entrada", quantidade: quantidade, valor: "18", grupo_material_uuid: cola.uuid,
                                                         cor_material_uuid: cor.uuid, largura: "1,40 m", consumo_g_m2: "120", **campos } }
  end

  it "sets the unit on the group page, and keeps it once the group has a material" do
    grupo = GrupoMaterial.create!(nome: "Tinta")
    patch grupo_material_path(grupo), params: { grupo_material: { unidade: "kg" } }
    expect(grupo.reload.unidade).to eq("kg")

    entrada
    get edit_grupo_material_path(cola)
    pagina = Nokogiri::HTML(response.body)
    expect(pagina.css(".grupo-unidade input[disabled]").map { |radio| radio["value"] }).to eq(%w[m kg])
    expect(pagina.at_css("[data-unidade-fixa]").text).to eq("Não muda: o grupo já tem 1 material.")
    patch grupo_material_path(cola), params: { grupo_material: { unidade: "m" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(cola.reload.unidade).to eq("kg")
  end

  it "sends the unit with the group to the stock entry" do
    cola
    get grupos_materiais_path(q: "Col")
    expect(response.parsed_body.first).to include("unidade" => "kg", "atributos" => { "consumo_g_m2" => true })
  end

  it "registers a cola by its consumption, without a width, as a ligante counted in kg" do
    entrada
    material = MateriaPrima.sole
    expect([ material.largura, material.consumo_g_m2.to_f, material.tipo ]).to eq([ "", 120.0, "filme" ])
    expect(flash[:notice]).to eq("Movement registered: In 1.5 kg of Cola-Branco-120 g/m² (Empresa).")
    # The same cola again is the same material.
    expect { entrada(quantidade: "0,25") }.not_to change(MateriaPrima, :count)
  end

  it "shows the stock, the price and the ledger in kg" do
    entrada
    entrada(quantidade: "0,025")
    MateriaPrima.sole.update!(preco_metro: 25)
    get materiais_path
    pagina = Nokogiri::HTML(response.body)
    linha = pagina.at_css("tr[data-material='#{MateriaPrima.sole.uuid}']")
    expect(linha.at_css("[data-saldo='empresa']").text).to eq("1,525 kg")
    expect(linha.at_css("input[name='materia_prima[preco_metro]']")["placeholder"]).to eq("R$ / kg")
    expect(pagina.css(".movimentos-tabela tbody tr").map { |tr| tr.css("td")[4].text }).to contain_exactly("1,5 kg", "0,025 kg")
    expect(pagina.css(".movimentos-tabela tbody tr").map { |tr| tr.css("td")[6].text }.uniq).to eq([ "$18.00/kg" ])
  end
end
