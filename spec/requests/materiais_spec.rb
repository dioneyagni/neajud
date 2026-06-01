require "rails_helper"

RSpec.describe "Materiais", type: :request do
  let(:client) {
    c = Client.find_by(name: "Test Client") || Client.create!(name: "Test Client", responsible: "Test")
    c
  }
  let(:grupo) { GrupoMaterial.find_or_create_by!(nome: "Oxford") }
  let(:cor) { CorMaterial.find_or_create_by!(nome: "Vermelho") }

  describe "POST /materiais" do
    it "creates a movimento_estoque and auto-creates materia_prima" do
      expect {
        post materiais_path, params: {
          movimento_estoque: {
            client_id: client.id,
            tipo: "entrada",
            grupo_material_id: grupo.id,
            cor_material_id: cor.id,
            largura: "1,40",
            gramatura: "100g",
            quantidade: "10",
            valor: ""
          }
        }
      }.to change(MovimentoEstoque, :count).by(1)
       .and change(MateriaPrima, :count).by(1)

      expect(response).to redirect_to(materiais_path)
      follow_redirect!
      expect(response.body).to include("Movement registered")
    end

    it "normalizes comma to period in largura and valor" do
      post materiais_path, params: {
        movimento_estoque: {
          client_id: client.id,
          tipo: "entrada",
          grupo_material_id: grupo.id,
          cor_material_id: cor.id,
          largura: "1,40",
          gramatura: "100g",
          quantidade: "5",
          valor: "10,50"
        }
      }

      expect(response).to redirect_to(materiais_path)
      mp = MateriaPrima.last
      expect(mp.largura).to eq("1.40")
      mov = MovimentoEstoque.last
      expect(mov.valor).to eq(10.5)
    end

    it "reuses existing materia_prima with matching attributes" do
      mp = MateriaPrima.create!(
        grupo_material: grupo, cor_material: cor,
        largura: "1.40", gramatura: "100g"
      )

      expect {
        post materiais_path, params: {
          movimento_estoque: {
            client_id: client.id,
            tipo: "entrada",
            grupo_material_id: grupo.id,
            cor_material_id: cor.id,
            largura: "1.40",
            gramatura: "100g",
            quantidade: "3",
            valor: ""
          }
        }
      }.to change(MateriaPrima, :count).by(0)
       .and change(MovimentoEstoque, :count).by(1)
    end

    it "redirects with alert when required fields are missing" do
      post materiais_path, params: {
        movimento_estoque: {
          client_id: "", tipo: "", grupo_material_id: "",
          cor_material_id: "", largura: "", gramatura: "",
          quantidade: ""
        }
      }

      expect(response).to redirect_to(materiais_path)
      follow_redirect!
      expect(response.body).to include("Invalid material")
    end

    it "creates saida movement" do
      post materiais_path, params: {
        movimento_estoque: {
          client_id: client.id,
          tipo: "saida",
          grupo_material_id: grupo.id,
          cor_material_id: cor.id,
          largura: "1.40",
          gramatura: "100g",
          quantidade: "2.5",
          valor: ""
        }
      }

      expect(response).to redirect_to(materiais_path)
      expect(MovimentoEstoque.last.tipo).to eq("saida")
      expect(MovimentoEstoque.last.quantidade).to eq(2.5)
    end
  end

  describe "GET /materiais" do
    it "renders the index page" do
      get materiais_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Materials Inventory")
      expect(response.body).to include('href="/movimentos/new"')
    end

    it "shows existing movements in the ledger" do
      mp = MateriaPrima.create!(
        grupo_material: grupo, cor_material: cor,
        largura: "1.40", gramatura: "100g"
      )
      MovimentoEstoque.create!(
        client: client, materia_prima: mp,
        tipo: "entrada", quantidade: 10
      )

      get materiais_path
      expect(response.body).to include("Oxford")
      expect(response.body).to include("Vermelho")
    end

    it "renders the total row" do
      get materiais_path
      expect(response.body).to include("Total")
    end
  end

  describe "GET /materiais/new" do
    it "renders the form page" do
      get new_material_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Register Movement")
      expect(response.body).to include("Search client")
      expect(response.body).to include("Search group")
    end
  end

  describe "GET /materiais/grupos" do
    it "returns JSON of groups" do
      grupo
      get grupos_materiais_path
      expect(response).to have_http_status(:ok)
      json = response.parsed_body
      expect(json).to be_an(Array)
      names = json.map { |g| g["nome"] }
      expect(names).to include("Oxford")
    end

    it "filters groups by search query" do
      GrupoMaterial.create!(nome: "Offset")
      GrupoMaterial.create!(nome: "Reciclado")
      get grupos_materiais_path, params: { q: "Off" }
      json = response.parsed_body
      names = json.map { |g| g["nome"] }
      expect(names).to contain_exactly("Offset")
    end
  end
end
