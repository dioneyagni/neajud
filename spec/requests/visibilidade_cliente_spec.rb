require "rails_helper"

# Etapa 2.8 (3a, decided 10/10/2026): what a cliente final sees by kind — the
# dono's default grid (/visibilidade), each client's exceptions (its page,
# "gerenciar usuários"), and what each kind opens or closes on the pages.
RSpec.describe "Visibilidade para o cliente", type: :request do
  let(:client) { create(:client, name: "Cliente Alfa") }
  let(:molde) { create(:molde, client: client, sufixo: "Alfa", preco: 987.65) }
  let(:arte) { create(:arquivo, client: client, molde: molde, filename: "arte-alfa") }

  def entrar_como_cliente_final(visibilidade = {})
    client.update!(visibilidade: visibilidade)
    funcao = create(:funcao, :para_cliente, niveis: (Autorizacao::AREAS - Autorizacao::AREAS_DA_EQUIPE).index_with(1))
    entrar_como(create(:vinculo, user: create(:user), funcao: funcao, client: client).user)
  end

  describe "the dono's default grid" do
    it "lists the six kinds with their defaults" do
      get edit_visibilidade_path
      expect(response.body).to include("Arquivo original", "Cortes (DXF)", "Valores")
      expect(response.body).to include('name="tipos[cortes]" value="0" checked')
    end

    it "saves the grid" do
      patch visibilidade_path, params: { tipos: { cortes: "1", estoque: "0" } }
      expect(response).to redirect_to(edit_visibilidade_path)
      expect(Empresa.atual.visibilidade_cliente).to include("cortes" => true, "estoque" => false, "pedidos" => true)
    end
  end

  describe "a client's exceptions" do
    it "saves them, a kind on the default left out, and comes back to the client's page" do
      patch visibilidade_client_path(client), params: { tipos: { cortes: "1", valores: "0", pedidos: "padrao" } }
      expect(response).to redirect_to(client_path(client, anchor: "visibilidade"))
      expect(client.reload.visibilidade).to eq({ "cortes" => true, "valores" => false })
    end

    it "is shown on the client's page with the default each kind follows" do
      get client_path(client)
      expect(response.body).to include("Visibilidade para o cliente", "Default (closed)", "Default (open)")
    end
  end

  describe "what the cliente final sees" do
    it "hides the menu of a closed kind and starts on the gallery when the pedidos are closed" do
      user = entrar_como_cliente_final("pedidos" => false, "moldes" => false)
      get pedidos_path
      expect(response.body).not_to include(">Moldes<")
      delete session_path
      post session_path, params: { email_address: user.email_address, password: "senha-segura-123" }
      expect(response).to redirect_to(root_url)
    end

    it "shows the price per pair with valores open, never the cost or the margin" do
      pedido = create(:pedido, client: client)
      create(:item_pedido, pedido: pedido, arquivo: arte).grades.create!(tamanho_nome: molde.modelo.produto.grade.first, quantidade: 1)
      entrar_como_cliente_final("valores" => true)
      get molde_path(molde)
      expect(response.body).to include("R$ 987,65")
      get pedido_path(pedido)
      expect(response.body).to include("Preço / par")
      expect(response.body).not_to include("Custo", "Margem")
    end

    # Valores closed by default: the price is the empresa's to show.
    it "shows no price while valores is closed" do
      entrar_como_cliente_final
      get molde_path(molde)
      expect(response.body).not_to include("987,65")
    end

    it "downloads an original only while that kind is open" do
      entrar_como_cliente_final("original" => true)
      get arquivo_path(arte)
      expect(response.body).to include("Download Original")
      get download_arquivo_path(arte)
      expect(response).not_to have_http_status(:forbidden)
    end

    # The client approves (4/5): he sees every version, but which one is in use is the team's.
    it "sees the arte's versions without choosing the one in use" do
      2.times { |n| create(:arquivo_version, arquivo: arte, version_number: n + 1) }
      entrar_como_cliente_final
      get arquivo_path(arte)
      expect(response.body).to include("v1", "v2")
      expect(response.body).not_to include("Usar esta versão")
    end

    it "answers 404 to the pedido's Corte page while the cortes are closed" do
      pedido = create(:pedido, client: client)
      entrar_como_cliente_final
      get corte_pedido_path(pedido)
      expect(response).to have_http_status(:not_found)
    end
  end
end
