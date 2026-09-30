require "rails_helper"

# Etapa 1.1 (3/5): modelos are the official Neajud list — the company only
# sees them (config/catalogo_oficial.yml, CatalogoOficial).
RSpec.describe "Modelos", type: :request do
  let(:calcado) { create(:produto, nome: "Calçado", grade: (18..46).map(&:to_s)) }

  describe "GET /modelos" do
    it "lists the official modelos by produto, with abbreviation and grade" do
      create(:modelo, nome: "Jogging", abreviacao: "JGG", produto: calcado)
      get modelos_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Calçado", "Grade 18–46", "Jogging", "JGG")
    end

    # The company can't register, edit or delete a modelo: it asks Neajud.
    it "offers no way to create, edit or delete one" do
      create(:modelo, produto: calcado)
      get modelos_path
      expect(response.body).not_to include("New Modelo", ">Edit<", ">Delete<")
    end

    it "leaves out modelos that left the list (in the trash)" do
      create(:modelo, nome: "Tenis Baixo", produto: calcado).excluir!(changed_by: CatalogoOficial::AUTORIA)
      get modelos_path
      expect(response.body).not_to include("Tenis Baixo")
    end
  end

  describe "GET /modelos/:id" do
    it "shows the modelo with its produto and abbreviation" do
      modelo = create(:modelo, nome: "Jogging", abreviacao: "JGG", produto: calcado)
      get modelo_path(modelo)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Jogging", "Calçado", "JGG")
    end
  end

  describe "GET /modelos/search" do
    it "returns matching modelos as JSON, with the abbreviation" do
      create(:modelo, nome: "Jogging", abreviacao: "JGG")
      get search_modelos_path, params: { q: "Jog" }
      expect(JSON.parse(response.body).map { |m| [ m["nome"], m["abreviacao"] ] }).to eq([ [ "Jogging", "JGG" ] ])
    end
  end

  describe "the editing routes are gone" do
    it "has no create, update or destroy" do
      modelo = create(:modelo)
      expect { post "/modelos", params: { modelo: { nome: "X" } } }.not_to change(Modelo, :count)
      expect(response).to have_http_status(:not_found)
      patch "/modelos/#{modelo.uuid}", params: { modelo: { nome: "Y" } }
      expect(response).to have_http_status(:not_found)
      delete "/modelos/#{modelo.uuid}"
      expect(response).to have_http_status(:not_found)
      expect(modelo.reload).to have_attributes(nome: modelo.nome, excluido?: false)
    end
  end
end
