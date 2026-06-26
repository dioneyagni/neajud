require "rails_helper"

RSpec.describe "Movimentos", type: :request do
  let(:client) { create(:client) }
  let(:grupo) { GrupoMaterial.find_or_create_by!(nome: "Oxford") }
  let(:cor) { CorMaterial.find_or_create_by!(nome: "Azul") }

  describe "GET /movimentos" do
    it "renders the index page" do
      get movimentos_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Movement History")
    end

    it "lists recent movements" do
      mp = MateriaPrima.create!(grupo_material: grupo, cor_material: cor, largura: "1.40", gramatura: "100g")
      MovimentoEstoque.create!(client: client, materia_prima: mp, tipo: "entrada", quantidade: 5)

      get movimentos_path
      expect(response.body).to include("Oxford")
      expect(response.body).to include("Azul")
    end
  end

  describe "GET /movimentos/new" do
    it "renders the form page" do
      get new_movimento_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Register Movement")
    end
  end

  describe "POST /movimentos" do
    it "creates a movimento_estoque" do
      expect {
        post movimentos_path, params: {
          movimento_estoque: {
            client_id: client.id,
            tipo: "entrada",
            grupo_material_id: grupo.id,
            cor_material_id: cor.id,
            largura: "1,40",
            gramatura: "100g",
            quantidade: "10"
          }
        }
      }.to change(MovimentoEstoque, :count).by(1)

      expect(response).to redirect_to(materiais_path)
      follow_redirect!
      expect(response.body).to include("Movement registered")
    end

    it "renders new with alert when material is invalid" do
      post movimentos_path, params: {
        movimento_estoque: { client_id: "", tipo: "", grupo_material_id: "", cor_material_id: "", largura: "", gramatura: "", quantidade: "" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Invalid material")
    end

    it "renders new with errors when movimento fails to save" do
      mp = MateriaPrima.create!(grupo_material: grupo, cor_material: cor, largura: "1.40", gramatura: "100g")

      post movimentos_path, params: {
        movimento_estoque: {
          client_id: "", tipo: "entrada",
          grupo_material_id: grupo.id, cor_material_id: cor.id,
          largura: "1.40", gramatura: "100g", quantidade: "5"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "reuses existing materia_prima" do
      mp = MateriaPrima.create!(grupo_material: grupo, cor_material: cor, largura: "1.40", gramatura: "100g")

      expect {
        post movimentos_path, params: {
          movimento_estoque: {
            client_id: client.id, tipo: "entrada",
            grupo_material_id: grupo.id, cor_material_id: cor.id,
            largura: "1.40", gramatura: "100g", quantidade: "3"
          }
        }
      }.to change(MateriaPrima, :count).by(0)
       .and change(MovimentoEstoque, :count).by(1)
    end
  end
end
