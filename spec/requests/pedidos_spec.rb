require "rails_helper"

RSpec.describe "Pedidos", type: :request do
  let(:arquivo) { create(:arquivo, category: "artes") }
  let(:grupo) { GrupoMaterial.find_or_create_by!(nome: "Oxford") }
  let(:cor) { CorMaterial.find_or_create_by!(nome: "Vermelho") }
  let(:materia_prima) do
    MateriaPrima.create!(grupo_material: grupo, cor_material: cor, largura: "1.40", gramatura: "100g")
  end

  describe "GET /pedidos" do
    it "returns http success" do
      get pedidos_path
      expect(response).to have_http_status(:success)
    end

    it "lists pedidos" do
      create(:pedido)
      get pedidos_path
      expect(response.body).to include("pedidos")
    end

    it "shows empty state" do
      get pedidos_path
      expect(response.body).to include("No pedidos yet")
    end
  end

  describe "GET /pedidos/:uuid" do
    it "shows pedido details" do
      pedido = create(:pedido)
      item = create(:item_pedido, pedido: pedido, arquivo: arquivo)
      create(:item_pedido_grade, item_pedido: item, tamanho_nome: "P", quantidade: 5)
      get pedido_path(pedido)
      expect(response).to have_http_status(:success)
      expect(response.body).to include(arquivo.filename)
      expect(response.body).to include("5")
    end
  end

  describe "POST /pedidos" do
    it "creates a rascunho pedido" do
      expect { post pedidos_path }.to change(Pedido, :count).by(1)
      expect(Pedido.last.status).to eq("rascunho")
    end

    it "redirects to resumo" do
      post pedidos_path
      expect(response).to redirect_to(resumo_pedido_path(Pedido.last))
    end
  end

  describe "DELETE /pedidos/:uuid" do
    it "destroys the pedido" do
      pedido = create(:pedido)
      expect { delete pedido_path(pedido) }.to change(Pedido, :count).by(-1)
    end

    it "returns 404 for non-existent pedido" do
      delete pedido_path(uuid: "nonexistent")
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /pedidos/adicionar_item" do
    it "adds item, auto-creating draft when none exists" do
      expect {
        post adicionar_item_pedidos_path, params: { arquivo_uuid: arquivo.uuid }
      }.to change(Pedido, :count).by(1)
       .and change(ItemPedido, :count).by(1)

      expect(response).to have_http_status(:success)
      json = response.parsed_body
      expect(json["ok"]).to be true
    end

    it "reuses existing draft from session across requests" do
      post adicionar_item_pedidos_path, params: { arquivo_uuid: arquivo.uuid }
      pedido = Pedido.last

      arte2 = create(:arquivo, filename: "outra", extension: "tif", mime_type: "image/tiff", category: "artes")
      post adicionar_item_pedidos_path, params: { arquivo_uuid: arte2.uuid }

      expect(response).to have_http_status(:success)
      expect(pedido.itens_pedido.count).to eq(2)
    end

    it "sets pedido client_id from arte when arte has a client" do
      client = create(:client)
      arte_com_cliente = create(:arquivo, category: "artes", client: client)

      post adicionar_item_pedidos_path, params: { arquivo_uuid: arte_com_cliente.uuid }

      expect(response).to have_http_status(:success)
      pedido = Pedido.last
      expect(pedido.client_id).to eq(client.id)
    end

    it "creates separate pedidos for different clients" do
      client_a = create(:client, name: "Client A")
      client_b = create(:client, name: "Client B")
      arte_a = create(:arquivo, category: "artes", client: client_a)
      arte_b = create(:arquivo, category: "artes", client: client_b)

      post adicionar_item_pedidos_path, params: { arquivo_uuid: arte_a.uuid }
      pedido_a = Pedido.find_by!(client_id: client_a.id)
      expect(pedido_a.status).to eq("rascunho")

      post adicionar_item_pedidos_path, params: { arquivo_uuid: arte_b.uuid }
      pedido_b = Pedido.find_by!(client_id: client_b.id)
      expect(pedido_b.status).to eq("rascunho")

      expect(pedido_a.uuid).not_to eq(pedido_b.uuid)
    end

    it "includes material when specified" do
      post adicionar_item_pedidos_path, params: {
        arquivo_uuid: arquivo.uuid,
        materia_prima_id: materia_prima.id
      }

      expect(response).to have_http_status(:success)
      item = ItemPedido.last
      expect(item.materia_prima_id).to eq(materia_prima.id)
    end

    it "includes grade quantities" do
      post adicionar_item_pedidos_path, params: {
        arquivo_uuid: arquivo.uuid,
        grade: { "P" => "3", "M" => "2" }
      }

      expect(response).to have_http_status(:success)
      item = ItemPedido.last
      expect(item.grades.count).to eq(2)
      expect(item.grades.find_by(tamanho_nome: "P").quantidade).to eq(3)
      expect(item.grades.find_by(tamanho_nome: "M").quantidade).to eq(2)
    end

    it "returns 422 for non-existent arquivo" do
      post adicionar_item_pedidos_path, params: { arquivo_uuid: "nonexistent-uuid" }
      expect(response).to have_http_status(:unprocessable_content)
      json = response.parsed_body
      expect(json["ok"]).to be false
    end
  end

  describe "DELETE /pedidos/:uuid/remover_item" do
    it "removes an item from the pedido" do
      pedido = create(:pedido)
      item = create(:item_pedido, pedido: pedido, arquivo: arquivo)

      expect {
        delete remover_item_pedido_path(pedido, id: item.uuid)
      }.to change { pedido.itens_pedido.count }.by(-1)

      expect(response).to redirect_to(resumo_pedido_path(pedido))
    end
  end

  describe "POST /pedidos/:uuid/confirmar" do
    it "splits items by client and creates confirmado pedidos" do
      client_a = create(:client)
      client_b = create(:client)
      arte_a = create(:arquivo, filename: "arte_a", extension: "tif", mime_type: "image/tiff", category: "artes", client: client_a)
      arte_b = create(:arquivo, filename: "arte_b", extension: "tif", mime_type: "image/tiff", category: "artes", client: client_b)

      pedido = create(:pedido)
      create(:item_pedido, pedido: pedido, arquivo: arte_a)
      create(:item_pedido, pedido: pedido, arquivo: arte_b)

      expect {
        post confirmar_pedido_path(pedido)
      }.to change(Pedido, :count).by(2)

      pedido.reload
      expect(pedido.status).to eq("cancelado")

      novos = Pedido.where(status: "confirmado")
      expect(novos.count).to eq(2)
      expect(novos.pluck(:client_id)).to contain_exactly(client_a.id, client_b.id)
    end

    it "confirms single-client pedido in-place without duplication" do
      client = create(:client)
      arte = create(:arquivo, category: "artes", client: client)
      pedido = create(:pedido)
      create(:item_pedido, pedido: pedido, arquivo: arte)

      expect {
        post confirmar_pedido_path(pedido)
      }.not_to change(Pedido, :count)

      pedido.reload
      expect(pedido.status).to eq("confirmado")
      expect(pedido.client_id).to eq(client.id)
    end

    it "redirects with alert if already confirmed" do
      pedido = create(:pedido, status: "confirmado")
      post confirmar_pedido_path(pedido)
      expect(response).to redirect_to(pedidos_path)
      follow_redirect!
      expect(response.body).to include("already confirmed")
    end
  end

  describe "GET /pedidos/:uuid/resumo" do
    it "renders the show template" do
      pedido = create(:pedido)
      get resumo_pedido_path(pedido)
      expect(response).to have_http_status(:success)
    end
  end
end
