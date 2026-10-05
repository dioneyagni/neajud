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
    it "moves the pedido to the trash, keeping its items" do
      pedido = create(:pedido)
      create(:item_pedido, pedido: pedido, arquivo: arquivo)
      expect { delete pedido_path(pedido) }.not_to change(Pedido, :count)
      expect(pedido.reload).to be_excluido
      expect(pedido.itens_pedido.count).to eq(1)
    end

    it "hides the trashed pedido from the index but keeps its page, frozen" do
      pedido = create(:pedido, deleted_at: 1.day.ago)
      get pedidos_path
      expect(response.body).not_to include(pedido.uuid.first(8))
      get resumo_pedido_path(pedido)
      expect(response.body).to include("badge-excluido")
      expect(response.body).not_to include("Excluir Rascunho")
    end

    it "refuses to change a trashed pedido" do
      pedido = create(:pedido)
      item = create(:item_pedido, pedido: pedido, arquivo: arquivo)
      pedido.update_columns(deleted_at: Time.current)
      expect { delete remover_item_pedido_path(pedido, id: item.uuid) }.not_to change(ItemPedido, :count)
      expect(flash[:alert]).to include("in the trash")
    end

    it "does not add items to a trashed draft kept in the session" do
      post adicionar_item_pedidos_path, params: { arquivo_uuid: arquivo.uuid, grade: { "_total" => "1" } }
      trashed = Pedido.last
      trashed.update_columns(deleted_at: Time.current)
      post adicionar_item_pedidos_path, params: { arquivo_uuid: arquivo.uuid, grade: { "_total" => "1" } }
      expect(response.parsed_body["pedido_uuid"]).not_to eq(trashed.uuid)
      expect(trashed.itens_pedido.count).to eq(1)
    end

    it "returns 404 for non-existent pedido" do
      delete pedido_path(uuid: "nonexistent")
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /pedidos/adicionar_item" do
    it "adds item, auto-creating draft when none exists" do
      expect {
        post adicionar_item_pedidos_path, params: { arquivo_uuid: arquivo.uuid, grade: { "_total" => "1" } }
      }.to change(Pedido, :count).by(1)
       .and change(ItemPedido, :count).by(1)

      expect(response).to have_http_status(:success)
      json = response.parsed_body
      expect(json["ok"]).to be true
    end

    it "reuses existing draft from session across requests" do
      post adicionar_item_pedidos_path, params: { arquivo_uuid: arquivo.uuid, grade: { "_total" => "1" } }
      pedido = Pedido.last

      arte2 = create(:arquivo, filename: "outra", extension: "tif", mime_type: "image/tiff", category: "artes")
      post adicionar_item_pedidos_path, params: { arquivo_uuid: arte2.uuid, grade: { "_total" => "1" } }

      expect(response).to have_http_status(:success)
      expect(pedido.itens_pedido.count).to eq(2)
    end

    it "sets pedido client_id from arte when arte has a client" do
      client = create(:client)
      arte_com_cliente = create(:arquivo, category: "artes", client: client)

      post adicionar_item_pedidos_path, params: { arquivo_uuid: arte_com_cliente.uuid, grade: { "_total" => "1" } }

      expect(response).to have_http_status(:success)
      pedido = Pedido.last
      expect(pedido.client_id).to eq(client.id)
    end

    it "creates separate pedidos for different clients" do
      client_a = create(:client, name: "Client A")
      client_b = create(:client, name: "Client B")
      arte_a = create(:arquivo, category: "artes", client: client_a)
      arte_b = create(:arquivo, category: "artes", client: client_b)

      post adicionar_item_pedidos_path, params: { arquivo_uuid: arte_a.uuid, grade: { "_total" => "1" } }
      pedido_a = Pedido.find_by!(client_id: client_a.id)
      expect(pedido_a.status).to eq("rascunho")

      post adicionar_item_pedidos_path, params: { arquivo_uuid: arte_b.uuid, grade: { "_total" => "1" } }
      pedido_b = Pedido.find_by!(client_id: client_b.id)
      expect(pedido_b.status).to eq("rascunho")

      expect(pedido_a.uuid).not_to eq(pedido_b.uuid)
    end

    it "includes material when specified" do
      post adicionar_item_pedidos_path, params: {
        arquivo_uuid: arquivo.uuid,
        materia_prima_uuid: materia_prima.uuid,
        grade: { "_total" => "1" }
      }

      expect(response).to have_http_status(:success)
      item = ItemPedido.last
      expect(item.materia_prima_id).to eq(materia_prima.id)
    end

    # Etapa 1.2 (3/3): by individual size, in the molde's stretch of the grade.
    it "includes grade quantities by individual size, and the arte of the file" do
      arte = create(:arquivo, molde: create(:molde, tamanho_inicial: "29", tamanho_final: "31"))
      post adicionar_item_pedidos_path, params: { arquivo_uuid: arte.uuid, grade: { "29" => "3", "30" => "2" } }

      expect(response).to have_http_status(:success)
      item = ItemPedido.last
      expect([ item.arte, item.grades.order(:tamanho_nome).map { |g| [ g.tamanho_nome, g.quantidade ] } ]).to eq([ arte.arte, [ [ "29", 3 ], [ "30", 2 ] ] ])
    end

    it "refuses a size outside the arte's grade, naming it and the expected ones" do
      arte = create(:arquivo, molde: create(:molde, tamanho_inicial: "29", tamanho_final: "30"))
      post adicionar_item_pedidos_path, params: { arquivo_uuid: arte.uuid, grade: { "29-30" => "3" } }
      expect([ response.status, response.parsed_body["error"] ]).to eq([ 422, "Sizes 29-30 are not in this arte's grade; expected some of 29, 30" ])
    end

    it "adds to the pedido it is asked for (the pedido page's picker)" do
      pedido = create(:pedido)
      post adicionar_item_pedidos_path, params: { arquivo_uuid: arquivo.uuid, pedido_uuid: pedido.uuid, grade: { "_total" => "1" } }
      expect(pedido.itens_pedido.count).to eq(1)
    end

    it "refuses adding to a pedido with the old grade" do
      pedido = create(:pedido, grade_antiga: true)
      post adicionar_item_pedidos_path, params: { arquivo_uuid: arquivo.uuid, pedido_uuid: pedido.uuid, grade: { "_total" => "1" } }
      expect(response.parsed_body["error"]).to include("expected a draft, got an old-grade pedido")
    end

    it "stores every piece of the arte's molde, marking the ones without arte as pending" do
      lateral, lingua = create(:peca, nome: "Lateral"), create(:peca, nome: "Língua")
      molde = create(:molde, partes: [ lateral, lingua ])
      arte = create(:arquivo, category: "artes", molde: molde, peca: lateral)

      post adicionar_item_pedidos_path, params: { arquivo_uuid: arte.uuid, grade: { "_total" => "1" } }

      rows = ItemPedido.last.item_pedido_pecas
      expect(rows.map { |r| [ r.peca.nome, r.arquivo, r.estado ] })
        .to eq([ [ "Lateral", arte, :incluida ], [ "Língua", nil, :pendente ] ])
    end

    it "stores the pieces left unchecked in the modal as excluded" do
      lateral, lingua = create(:peca, nome: "Lateral"), create(:peca, nome: "Língua")
      molde = create(:molde, partes: [ lateral, lingua ])
      arte_lateral = create(:arquivo, category: "artes", molde: molde, peca: lateral)
      arte_lingua = create(:arquivo, category: "artes", molde: molde, peca: lingua)

      post adicionar_item_pedidos_path, params: { arquivo_uuid: arte_lateral.uuid, excluir_arquivos: [ arte_lingua.uuid ], grade: { "_total" => "1" } }

      expect(ItemPedido.last.item_pedido_pecas.map { |r| [ r.peca.nome, r.estado ] })
        .to eq([ [ "Lateral", :incluida ], [ "Língua", :excluida ] ])
    end

    it "returns 422 for non-existent arquivo" do
      post adicionar_item_pedidos_path, params: { arquivo_uuid: "nonexistent-uuid", grade: { "_total" => "1" } }
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
      create(:item_pedido, :com_quantidade, pedido: pedido, arquivo: arte_a)
      create(:item_pedido, :com_quantidade, pedido: pedido, arquivo: arte_b)

      expect {
        post confirmar_pedido_path(pedido)
      }.to change(Pedido, :count).by(2)

      pedido.reload
      expect(pedido.status).to eq("cancelado")

      novos = Pedido.where(status: "confirmado")
      expect(novos.count).to eq(2)
      expect(novos.pluck(:client_id)).to contain_exactly(client_a.id, client_b.id)
    end

    it "copies each item's pieces and their state into the split pedidos" do
      arte_a = create(:arquivo, category: "artes", client: create(:client))
      arte_b = create(:arquivo, category: "artes", client: create(:client))
      pedido = create(:pedido)
      item_a = create(:item_pedido, :com_quantidade, pedido: pedido, arquivo: arte_a)
      create(:item_pedido_peca, item_pedido: item_a, arquivo: arte_a, incluida: false)
      create(:item_pedido, :com_quantidade, pedido: pedido, arquivo: arte_b)

      post confirmar_pedido_path(pedido)

      copied = ItemPedido.joins(:pedido).where(pedidos: { status: "confirmado" }, arquivo: arte_a).sole
      expect(copied.item_pedido_pecas.map { |r| [ r.arquivo, r.estado ] }).to eq([ [ arte_a, :excluida ] ])
    end

    it "refuses to confirm while a piece has no arte, naming it" do
      pedido = create(:pedido)
      item = create(:item_pedido, :com_quantidade, pedido: pedido, arquivo: create(:arquivo, filename: "tenis-baixo"))
      create(:item_pedido_peca, item_pedido: item, peca: create(:peca, nome: "Língua"), arquivo: nil)

      expect { post confirmar_pedido_path(pedido) }.not_to change(Pedido, :count)

      expect(response).to redirect_to(resumo_pedido_path(pedido))
      expect(flash[:alert]).to include("Língua", "tenis-baixo")
      expect(pedido.reload.status).to eq("rascunho")
    end

    # 01/10/2026: a draft without client said nothing about who it is for.
    it "shows a draft without client the client it will get from its artes" do
      pedido = create(:pedido, client: nil)
      create(:item_pedido, pedido: pedido, arquivo: create(:arquivo, category: "artes", client: create(:client, name: "MKS")))
      get pedido_path(pedido)
      expect(response.body).to include("MKS (das artes)")
      create(:item_pedido, pedido: pedido, arquivo: create(:arquivo, category: "artes", client: create(:client, name: "GMS")))
      get pedido_path(pedido)
      expect(response.body).to include("será dividido por cliente ao confirmar: GMS, MKS")
    end

    it "refuses to confirm an item whose arte has no client" do
      pedido = create(:pedido, client: nil)
      create(:item_pedido, :com_quantidade, pedido: pedido, arquivo: create(:arquivo, category: "artes", client: nil, filename: "sem-dono"))
      post confirmar_pedido_path(pedido)
      expect(flash[:alert]).to include("Arte sem-dono sem cliente")
      expect(pedido.reload.status).to eq("rascunho")
    end

    it "confirms when pieces are only unchecked (the pedido goes without them)" do
      pedido = create(:pedido)
      item = create(:item_pedido, :com_quantidade, pedido: pedido)
      create(:item_pedido_peca, item_pedido: item, incluida: false)
      post confirmar_pedido_path(pedido)
      expect(pedido.reload.status).to eq("confirmado")
    end

    it "confirms single-client pedido in-place without duplication" do
      client = create(:client)
      arte = create(:arquivo, category: "artes", client: client)
      pedido = create(:pedido)
      create(:item_pedido, :com_quantidade, pedido: pedido, arquivo: arte)

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

  describe "PATCH /pedidos/:uuid/alternar_peca" do
    let(:pedido) { create(:pedido) }
    let(:item) { create(:item_pedido, pedido: pedido) }
    let!(:peca_row) { create(:item_pedido_peca, item_pedido: item) }

    def alternar(incluida, row: peca_row, target: pedido)
      patch alternar_peca_pedido_path(target), params: { id: row.item_pedido.uuid, peca_uuid: row.uuid, incluida: incluida }, as: :json
    end

    it "unchecks and re-checks a piece" do
      alternar("false")
      expect(response.parsed_body).to eq("ok" => true, "estado" => "excluida")
      expect(peca_row.reload.estado).to eq(:excluida)
      alternar("true")
      expect(peca_row.reload.estado).to eq(:incluida)
    end

    it "refuses changes once the pedido is no longer a draft" do
      pedido.update!(status: "confirmado")
      alternar("false")
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("confirmado")
      expect(peca_row.reload.estado).to eq(:incluida)
    end

    it "refuses a pending piece (no arte)" do
      pending_row = create(:item_pedido_peca, item_pedido: item, arquivo: nil)
      alternar("false", row: pending_row)
      expect(response).to have_http_status(:unprocessable_content)
      expect(pending_row.reload.incluida).to be true
    end

    it "refuses a value other than true/false, naming it" do
      alternar("maybe")
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include('"maybe"')
    end

    it "returns 404 for a piece of another pedido's item" do
      other_row = create(:item_pedido_peca)
      alternar("false", row: other_row)
      expect(response).to have_http_status(:not_found)
      expect(other_row.reload.incluida).to be true
    end
  end

  describe "GET /pedidos/:uuid pieces frame" do
    let(:pedido) { create(:pedido) }
    let(:item) { create(:item_pedido, pedido: pedido) }

    it "shows each piece with its state and a checkbox for pieces with arte" do
      create(:item_pedido_peca, item_pedido: item, peca: create(:peca, nome: "Lateral"), position: 0)
      create(:item_pedido_peca, item_pedido: item, peca: create(:peca, nome: "Língua"), incluida: false, position: 1)
      create(:item_pedido_peca, item_pedido: item, peca: create(:peca, nome: "Calcanhar"), arquivo: nil, position: 2)
      get pedido_path(pedido)
      html = Nokogiri::HTML(response.body)
      cards = html.css(".pedido-peca")
      expect(cards.map { |c| c[:class].split.last }).to eq(%w[pedido-peca--incluida pedido-peca--excluida pedido-peca--pendente])
      expect(cards.map { |c| c.css(".pedido-peca-nome").text }).to eq(%w[Lateral Língua Calcanhar])
      expect(cards.map { |c| c.css("input.pedido-peca-check").size }).to eq([ 1, 1, 0 ])
      expect(cards[2].text).to include("sem arte", "Pendente")
    end

    it "shows no checkboxes on a confirmed pedido" do
      2.times { |n| create(:item_pedido_peca, item_pedido: item, position: n) }
      pedido.update!(status: "confirmado")
      get pedido_path(pedido)
      expect(Nokogiri::HTML(response.body).css("input.pedido-peca-check")).to be_empty
    end

    it "shows no checkbox for a single-piece item" do
      create(:item_pedido_peca, item_pedido: item)
      get pedido_path(pedido)
      expect(Nokogiri::HTML(response.body).css(".pedido-peca").size).to eq(1)
      expect(Nokogiri::HTML(response.body).css("input.pedido-peca-check")).to be_empty
    end
  end

  describe "GET /pedidos/:uuid/producao" do
    it "renders the Produção frame with checked pieces only" do
      pedido = create(:pedido)
      item = create(:item_pedido, pedido: pedido)
      item.grades.create!(tamanho_nome: "35", quantidade: 3)
      create(:item_pedido_peca, item_pedido: item, peca: create(:peca, nome: "Lateral"), position: 0)
      create(:item_pedido_peca, item_pedido: item, peca: create(:peca, nome: "Língua"), incluida: false, position: 1)

      get producao_pedido_path(pedido)

      html = Nokogiri::HTML(response.body)
      expect(html.at_css("turbo-frame#pedido-producao")).to be_present
      expect(html.css("tbody tr").map { |tr| tr["data-peca"] }).to eq([ "Lateral" ])
      expect(html.css("tbody tr td").map(&:text).map(&:strip).first(3)).to eq([ "Lateral", "3", "3" ])
    end
  end

  describe "GET /pedidos/:uuid/producao downloads" do
    it "turns each quantity into a download of that size's DXF, and warns on a size the corte lacks" do
      lateral = create(:peca, nome: "Lateral")
      corte = create(:arquivo, :corte, peca: lateral, filename: "24 AO 34 - CABEDAL")
      t34 = create(:tamanho, arquivo: corte, nome: "34")
      pedido = create(:pedido)
      item = create(:item_pedido, pedido: pedido)
      item.grades.create!(tamanho_nome: "34", quantidade: 2)
      item.grades.create!(tamanho_nome: "35", quantidade: 1)
      create(:item_pedido_peca, item_pedido: item, peca: lateral, arquivo: create(:arquivo, tamanho: t34))

      get producao_pedido_path(pedido)

      row = Nokogiri::HTML(response.body).at_css("tbody tr")
      link = row.at_css("td[data-tamanho='34'] a.producao-download")
      expect(link["href"]).to eq(download_tamanho_path(t34))
      expect(link["download"]).to eq("24 AO 34 - CABEDAL - 34.dxf")
      expect(link["data-turbo"]).to eq("false")
      expect(row.at_css("td[data-tamanho='35'] .producao-sem-dxf").text).to include("1", "sem DXF")
      expect(row.at_css("td.producao-corte").text.strip).to eq("24 AO 34 - CABEDAL")
    end
  end

  describe "pending pieces on the pedido pages" do
    let(:pedido) { create(:pedido) }

    before do
      item = create(:item_pedido, :com_quantidade, pedido: pedido)
      create(:item_pedido_peca, item_pedido: item, peca: create(:peca, nome: "Língua"), arquivo: nil)
    end

    it "lists them and disables Confirmar on the pedido page" do
      get pedido_path(pedido)
      html = Nokogiri::HTML(response.body)
      expect(html.at_css(".pedido-pendencias").text).to include("Língua")
      expect(html.at_css("form[action='#{confirmar_pedido_path(pedido)}'] button[disabled]")).to be_present
    end

    it "shows a pending badge instead of Confirmar in the list" do
      get pedidos_path
      html = Nokogiri::HTML(response.body)
      expect(html.at_css(".pedido-pendentes-badge").text).to include("1 pendente")
      expect(html.css("a[href='#{confirmar_pedido_path(pedido)}']")).to be_empty
    end
  end

  describe "no zero quantities, no missing corte" do
    it "refuses adicionar_item with total 0 without creating a pedido or item" do
      expect {
        post adicionar_item_pedidos_path, params: { arquivo_uuid: arquivo.uuid, grade: { "35" => "0", "36" => "0" } }
      }.not_to change { [ Pedido.count, ItemPedido.count ] }
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("quantidade total 0")
    end

    it "refuses adicionar_item with no grade at all" do
      post adicionar_item_pedidos_path, params: { arquivo_uuid: arquivo.uuid }
      expect(response).to have_http_status(:unprocessable_content)
    end

    it "refuses atualizar_item that would leave the item at 0, keeping the old grade" do
      pedido = create(:pedido)
      item = create(:item_pedido, pedido: pedido)
      item.grades.create!(tamanho_nome: "35", quantidade: 2)
      patch atualizar_item_pedido_path(pedido, id: item.uuid), params: { grade: { "35" => "0" } }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to include("use Remover")
      expect(item.grades.reload.map { |g| [ g.tamanho_nome, g.quantidade ] }).to eq([ [ "35", 2 ] ])
    end

    it "accepts atualizar_item zeroing one size while another keeps quantity" do
      pedido = create(:pedido)
      item = create(:item_pedido, pedido: pedido, arquivo: create(:arquivo, molde: create(:molde, tamanho_inicial: "35", tamanho_final: "36")))
      item.grades.create!(tamanho_nome: "35", quantidade: 2)
      item.grades.create!(tamanho_nome: "36", quantidade: 1)
      patch atualizar_item_pedido_path(pedido, id: item.uuid), params: { grade: { "35" => "0" } }, as: :json
      expect(response.parsed_body["ok"]).to be true
      expect(item.quantidade_total).to eq(1)
    end

    it "refuses to confirm a pedido with an item at 0" do
      pedido = create(:pedido)
      create(:item_pedido, pedido: pedido, arquivo: create(:arquivo, filename: "zerado"))
      post confirmar_pedido_path(pedido)
      expect(pedido.reload.status).to eq("rascunho")
      expect(flash[:alert]).to include("Item zerado com quantidade total 0")
    end

    it "refuses to confirm while a checked piece has no corte, listing it on the page" do
      pedido = create(:pedido)
      item = create(:item_pedido, :com_quantidade, pedido: pedido)
      create(:item_pedido_peca, item_pedido: item, peca: create(:peca, nome: "Lateral"), arquivo: create(:arquivo, filename: "28-GATO ROSA"))
      post confirmar_pedido_path(pedido)
      expect(pedido.reload.status).to eq("rascunho")
      expect(flash[:alert]).to include("Lateral sem arquivo de corte (arte 28-GATO ROSA)")
      get pedido_path(pedido)
      li = Nokogiri::HTML(response.body).at_css(".pedido-pendencia--sem_corte")
      expect(li.text).to include("28-GATO ROSA")
      expect(li.at_css("a")["href"]).to eq(arquivo_path(Arquivo.find_by!(filename: "28-GATO ROSA")))
    end
  end

  describe "Etapa 1.2 (3/3): the pedido by arte" do
    it "is calçado by default" do
      expect(create(:pedido).tipo).to eq("calcado")
    end

    it "keeps an old-grade pedido read only, even restored, saying why" do
      pedido = create(:pedido, grade_antiga: true)
      item = create(:item_pedido, pedido: pedido)
      patch atualizar_item_pedido_path(pedido, id: item.uuid), params: { grade: { "_total" => "2" } }, as: :json
      expect(response.parsed_body["error"]).to include("has the old grade")
      get resumo_pedido_path(pedido)
      expect(response.body).to include("formato antigo")
    end

    it "lists a molde's referências and artes for the picker, narrowing by referência" do
      molde = create(:molde)
      vinte = Referencia.do_molde!(molde, "20")
      bluey = create(:arquivo, molde: molde, referencia: vinte, nome: "Bluey")
      create(:arquivo, arte: bluey.arte, molde: molde, referencia: vinte, nome: "Bluey")
      gato = create(:arquivo, molde: molde, referencia: Referencia.do_molde!(molde, "21"), nome: "Gato")

      get artes_para_adicionar_pedidos_path(molde_uuid: molde.uuid), as: :json
      expect(response.parsed_body["referencias"].map { |r| r["nome"] }).to eq(%w[20 21])
      expect(response.parsed_body["artes"].map { |a| a["arquivo_uuid"] }).to contain_exactly(bluey.uuid, gato.uuid)
      get artes_para_adicionar_pedidos_path(molde_uuid: molde.uuid, referencia_uuid: vinte.uuid), as: :json
      expect(response.parsed_body["artes"].map { |a| a["titulo"] }).to eq([ "#{molde.codigo} · 20 · Bluey" ])
    end
  end
end
