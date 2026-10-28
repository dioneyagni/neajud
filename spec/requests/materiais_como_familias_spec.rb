require "rails_helper"
require_relative "../support/tecidos"

# Dublagem 1/5 (decided 27/10/2026): the group as a family — the page that
# sets it, the stock entry that asks what it asks, and the tecido pedido
# that offers only what prints, warning of a ressalva.
RSpec.describe "Materials as families", type: :request do
  let(:cor) { CorMaterial.find_or_create_by!(nome: "Branco") }
  let(:espuma) { GrupoMaterial.create!(nome: "Espuma") }

  describe "the groups page" do
    it "lists the groups with their roles and printing, and edits one" do
      espuma
      GrupoMaterial.create!(nome: "TNT", base: true, estampavel: "ressalvas", ressalva: "a cor fica mais clara")
      get grupo_materiais_path
      selos = Nokogiri::HTML(response.body).css(".grupos-item").to_h { |g| [ g["data-grupo"], g.css(".grupo-selo").map(&:text) ] }
      expect(selos).to eq("Espuma" => %w[Superfície Estampável], "TNT" => [ "Superfície", "Base", "Com ressalvas" ])

      patch grupo_material_path(espuma), params: { grupo_material: { superficie: "0", base: "1", estampavel: "nao", ressalva: "" },
                                                   pede: %w[fornecedor], obrigatorios: %w[densidade espessura_mm] }
      expect(response).to redirect_to(edit_grupo_material_path(espuma))
      expect(espuma.reload.slice(:superficie, :base, :estampavel, :atributos).values)
        .to eq([ false, true, "nao", { "densidade" => true, "espessura_mm" => true, "fornecedor" => false } ])
      get edit_grupo_material_path(espuma)
      marcados = Nokogiri::HTML(response.body).css("input[name='obrigatorios[]'][checked]").map { |i| i["value"] }
      expect(marcados).to eq(%w[densidade espessura_mm])
    end

    it "refuses ressalvas without their text, saying so" do
      patch grupo_material_path(espuma), params: { grupo_material: { estampavel: "ressalvas", ressalva: " " } }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Espuma: Ressalva diz qual é a ressalva")
      expect(espuma.reload.estampavel).to eq("sim")
    end
  end

  describe "the stock entry" do
    before { espuma.update!(atributos: { "densidade" => true, "espessura_mm" => true, "fornecedor" => false }) }

    def entrada(**campos)
      post movimentos_path, params: { movimento_estoque: { da_empresa: "true", tipo: "entrada", quantidade: "10", grupo_material_uuid: espuma.uuid,
                                                           cor_material_uuid: cor.uuid, largura: "1,40 m", gramatura: "100g", **campos } }
    end

    it "sends each group's attributes to the form" do
      get grupos_materiais_path(q: "Esp")
      expect(response.parsed_body.first["atributos"]).to eq("densidade" => true, "espessura_mm" => true, "fornecedor" => false)
    end

    it "refuses a new material without a required attribute, naming it and its group" do
      expect { entrada(espessura_mm: "3") }.not_to change(MateriaPrima, :count)
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Invalid material: Densidade é obrigatório no grupo Espuma.")
      # Regression: the width came back as the slider's middle (1,25 m).
      largura = Nokogiri::HTML(response.body).at_css("input[name='movimento_estoque[largura]']")["value"]
      expect(largura).to eq("1,40 m")
    end

    it "takes the asked attributes, drops what the group doesn't ask, and finds the material again" do
      entrada(densidade: "TC4", espessura_mm: "3,5", micras: "35")
      material = MateriaPrima.last
      expect([ material.nome_completo, material.gramatura, material.micras ]).to eq([ "Espuma TC4 3,5 mm-Branco-1.40 m", "", nil ])
      expect { entrada(densidade: "TC4", espessura_mm: "3,5") }.not_to change(MateriaPrima, :count)
      expect(MovimentoEstoque.where(materia_prima: material).sum(:quantidade)).to eq(20)
    end

    it "marks on the Materiais page what a group started requiring later" do
      entrada(densidade: "TC4", espessura_mm: "3")
      espuma.update!(atributos: espuma.atributos.merge("fornecedor" => true))
      get materiais_path
      expect(Nokogiri::HTML(response.body).at_css("[data-faltando]").text).to eq("falta fornecedor")
    end
  end

  describe "the tecido pedido" do
    let(:client) { create(:client) }
    let(:oxford) { criar_tecido }
    let(:tnt) { criar_tecido(grupo: "TNT") }
    let(:telinha) { criar_tecido(grupo: "Telinha") }
    let(:pedido) { create(:pedido, client: client, tipo: "tecido") }
    let(:item) { create(:item_pedido, pedido: pedido, materia_prima: oxford, metros: 2, arquivo: criar_obra_de_tecido("corrida", client: client).arquivos.first) }

    before do
      tnt.grupo_material.update!(estampavel: "ressalvas", ressalva: "a cor fica mais clara")
      telinha.grupo_material.update!(estampavel: "nao")
    end

    it "offers only what prints, and warns of a ressalva" do
      item.update!(materia_prima: tnt)
      get resumo_pedido_path(pedido)
      html = Nokogiri::HTML(response.body)
      expect(html.css(".pedido-tecido-material option").map(&:text).drop(1)).to contain_exactly("#{oxford.nome_completo} · saldo 0 m", "#{tnt.nome_completo} · saldo 0 m")
      expect(html.at_css(".pedido-tecido-ressalva").text).to eq("TNT estampa com ressalvas: a cor fica mais clara")
    end

    it "refuses a fabric that doesn't print, but keeps the item's own when its group stopped printing" do
      patch tecido_item_pedido_path(pedido), params: { item_uuid: item.uuid, materia_prima_uuid: telinha.uuid }
      expect([ response.status, item.reload.materia_prima ]).to eq([ 404, oxford ])
      oxford.grupo_material.update!(estampavel: "nao")
      patch tecido_item_pedido_path(pedido), params: { item_uuid: item.uuid, materia_prima_uuid: oxford.uuid, metros: "5" }
      expect([ item.reload.materia_prima, item.metros ]).to eq([ oxford, 5 ])
      get resumo_pedido_path(pedido)
      expect(Nokogiri::HTML(response.body).at_css(".pedido-tecido-material option[selected]").text).to start_with(oxford.nome_completo)
    end

    it "searches only what prints for a corrida or cor lisa" do
      [ oxford, tnt, telinha ]
      get search_materiais_path(tipo: "tecido", estampavel: "1")
      expect(response.parsed_body.map { |m| m["id"] }).to contain_exactly(oxford.uuid, tnt.uuid)
    end
  end
end
