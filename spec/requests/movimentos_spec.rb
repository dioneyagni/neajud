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
            client_uuid: client.uuid,
            tipo: "entrada",
            grupo_material_uuid: grupo.uuid,
            cor_material_uuid: cor.uuid,
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

    # Etapa 2.3 (decided 09/10/2026): the empresa's own stock has no client,
    # marked on the form so a forgotten client never becomes the empresa's.
    it "registers the empresa's own stock, and refuses a movement without client otherwise" do
      dados = { tipo: "entrada", grupo_material_uuid: grupo.uuid, cor_material_uuid: cor.uuid, largura: "1,40", gramatura: "100g", quantidade: "12,5" }
      post movimentos_path, params: { movimento_estoque: dados.merge(da_empresa: "true", client_uuid: client.uuid) }
      expect(MovimentoEstoque.last.attributes.values_at("client_id", "quantidade")).to eq([ nil, 12.5.to_d ])
      expect(flash[:notice]).to eq("Movement registered: In 12.5 m of Oxford-Azul-1.40-100g (Empresa).")

      expect { post movimentos_path, params: { movimento_estoque: dados.merge(da_empresa: "false", client_uuid: "") } }.not_to change(MovimentoEstoque, :count)
      expect(response.body).to include("Client is missing: choose the client, or mark the material as the empresa&#39;s")

      get movimentos_path
      expect(Nokogiri::HTML(response.body).at_css("tbody tr td:nth-child(2)").text).to eq("Empresa")
    end

    it "renders new with alert when material is invalid" do
      post movimentos_path, params: {
        movimento_estoque: { client_uuid: "", tipo: "", grupo_material_uuid: "", cor_material_uuid: "", largura: "", gramatura: "", quantidade: "" }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Invalid material")
    end

    it "renders new with errors when movimento fails to save" do
      mp = MateriaPrima.create!(grupo_material: grupo, cor_material: cor, largura: "1.40", gramatura: "100g")

      post movimentos_path, params: {
        movimento_estoque: {
          client_uuid: "", tipo: "entrada",
          grupo_material_uuid: grupo.uuid, cor_material_uuid: cor.uuid,
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
            client_uuid: client.uuid, tipo: "entrada",
            grupo_material_uuid: grupo.uuid, cor_material_uuid: cor.uuid,
            largura: "1.40", gramatura: "100g", quantidade: "3"
          }
        }
      }.to change(MateriaPrima, :count).by(0)
       .and change(MovimentoEstoque, :count).by(1)
    end
  end
end
