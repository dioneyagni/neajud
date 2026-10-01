require "rails_helper"

RSpec.describe "Lixeira", type: :request do
  describe "GET /lixeira" do
    it "lists trashed records by type with who deleted them" do
      create(:client, name: "Fagner").excluir!(changed_by: "10.0.0.9")
      create(:peca, nome: "Língua").excluir!(changed_by: "10.0.0.9")
      create(:client, name: "Active Corp")

      get lixeira_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Fagner", "Língua", "10.0.0.9")
      expect(response.body).not_to include("Active Corp")
    end

    it "says when the trash is empty" do
      get lixeira_path
      expect(response.body).to include("The trash is empty.")
    end
  end

  it "names the signed-in user who deleted each record" do
    client = create(:client, name: "Fagner")
    delete client_path(client)
    expect(client.reload.deleted_by_id).to eq(@usuario_logado.id)
    get lixeira_path
    expect(response.body).to include(@usuario_logado.nome)
  end

  describe "POST /lixeira/:tipo/:id/restaurar" do
    it "restores a client by uuid" do
      client = create(:client).tap { |c| c.excluir!(changed_by: "10.0.0.1") }
      post restaurar_lixeira_path(tipo: "clients", id: client.uuid)
      expect(client.reload).not_to be_excluido
      expect(response).to redirect_to(lixeira_path)
      expect(client.exclusao_logs.last).to have_attributes(acao: "restaurado", changed_by: "127.0.0.1")
    end

    # Etapa 1.1 (1/2): the integer id never leaves the server, so it must not
    # find anything either (a guessable sequence would reach other records).
    it "does not find a record by its integer id" do
      client = create(:client).tap { |c| c.excluir!(changed_by: "10.0.0.1") }
      post restaurar_lixeira_path(tipo: "clients", id: client.id)
      expect(response).to have_http_status(:not_found)
      expect(client.reload).to be_excluido
    end

    it "restores arquivos and pedidos by uuid" do
      arquivo = create(:arquivo).tap { |a| a.excluir!(changed_by: "10.0.0.1") }
      pedido = create(:pedido).tap { |p| p.excluir!(changed_by: "10.0.0.1") }
      post restaurar_lixeira_path(tipo: "arquivos", id: arquivo.uuid)
      post restaurar_lixeira_path(tipo: "pedidos", id: pedido.uuid)
      expect([ arquivo.reload, pedido.reload ].map(&:excluido?)).to eq([ false, false ])
    end

    it "404s for a record that is not in the trash" do
      client = create(:client)
      post restaurar_lixeira_path(tipo: "clients", id: client.id)
      expect(response).to have_http_status(:not_found)
    end

    it "404s for an unknown type (route constraint)" do
      post "/lixeira/users/1/restaurar"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "registering a name that is in the trash" do
    it "offers restoring the client instead of creating a duplicate" do
      create(:client, name: "Fagner").excluir!(changed_by: "10.0.0.1")
      expect { post clients_path, params: { client: { name: "fagner", responsible: "X" } } }.not_to change(Client, :count)
      expect(flash[:alert]).to include("is in the trash", "Lixeira")
    end

    it "does the same for peças" do
      create(:peca, nome: "Solado").excluir!(changed_by: "10.0.0.1")
      post pecas_path, params: { peca: { nome: "Solado" } }
      expect(flash[:alert]).to include("is in the trash")
    end

    # Moldes are numbered (Etapa 1.1, 4/5): a new one never collides with a
    # trashed one — it takes the next number. Modelos aren't registered by
    # the company at all (official list, 3/5).
    it "gives a new molde the next number instead of refusing a trashed name" do
      antigo = create(:molde, sufixo: "Tenis").tap { |m| m.excluir!(changed_by: "10.0.0.1") }
      post moldes_path, params: { molde: { sufixo: "Tenis", client_uuid: antigo.client.uuid, modelo_uuid: antigo.modelo.uuid } }
      expect(Molde.ativos.sole.nome).to eq("002-#{antigo.modelo.abreviacao} Tenis")
    end
  end
end
