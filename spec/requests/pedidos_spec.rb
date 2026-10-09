require "rails_helper"

RSpec.describe "Pedidos", type: :request do
  let(:arquivo) { create(:arquivo, category: "artes") }
  let(:grupo) { GrupoMaterial.find_or_create_by!(nome: "Oxford") }
  let(:cor) { CorMaterial.find_or_create_by!(nome: "Vermelho") }
  let(:materia_prima) do
    MateriaPrima.create!(grupo_material: grupo, cor_material: cor, largura: "1.40", gramatura: "100g")
  end

  # Etapa 1.2 (3/3): a molde whose Lateral DXF is Par (29-30, 31-32) and an
  # item of an arte with the Lateral production file of 29-30.
  def item_com_dxf(pedido:, grade: { "30" => 3 }, partes: [ create(:peca, nome: "Lateral") ])
    molde = create(:molde, partes: partes)
    corte = create(:arquivo, :corte, organized: true, peca: partes.first, client: molde.client, modelo: molde.modelo, filename: "24 AO 34 - CABEDAL").tap do |c|
      c.moldes << molde
      create(:tamanho, arquivo: c, nome: "29-30", numeros: %w[29 30], position: 1)
      create(:tamanho, arquivo: c, nome: "31-32", numeros: %w[31 32], position: 2)
    end
    arte = create(:arquivo, filename: "arte-lateral", molde: molde, client: molde.client, peca: partes.first, tamanho: corte.tamanhos.first)
    create(:item_pedido, pedido: pedido, arquivo: arte).tap do |item|
      item.compor_pecas!(MoldeComposicaoService.call(arte))
      grade.each { |numero, qtd| item.grades.create!(tamanho_nome: numero, quantidade: qtd) }
    end
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
      expect(response.body).not_to include("Excluir rascunho")
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

    it "refuses a size outside the product's grade, naming it; takes one just outside the molde's stretch" do
      arte = create(:arquivo, molde: create(:molde, tamanho_inicial: "29", tamanho_final: "30"))
      post adicionar_item_pedidos_path, params: { arquivo_uuid: arte.uuid, grade: { "29-30" => "3" } }
      expect([ response.status, response.parsed_body["error"] ]).to match([ 422, /\ASizes 29-30 are not in this arte's grade; expected some of 18, 19, / ])
      post adicionar_item_pedidos_path, params: { arquivo_uuid: arte.uuid, grade: { "31" => "1" } }
      expect(response).to have_http_status(:success)
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

    it "stores every part of the arte's molde, the arte's file of each (none yet for the Língua)" do
      lateral, lingua = create(:peca, nome: "Lateral"), create(:peca, nome: "Língua")
      molde = create(:molde, partes: [ lateral, lingua ])
      arte = create(:arquivo, category: "artes", molde: molde, peca: lateral)

      post adicionar_item_pedidos_path, params: { arquivo_uuid: arte.uuid, grade: { "30" => "1" } }

      rows = ItemPedido.last.item_pedido_pecas
      expect(rows.map { |r| [ r.peca.nome, r.arquivo, r.estado ] })
        .to eq([ [ "Lateral", arte, :incluida ], [ "Língua", nil, :incluida ] ])
    end

    it "stores the pieces left unchecked in the modal as excluded" do
      lateral, lingua = create(:peca, nome: "Lateral"), create(:peca, nome: "Língua")
      molde = create(:molde, partes: [ lateral, lingua ])
      arte_lateral = create(:arquivo, category: "artes", molde: molde, peca: lateral)
      arte_lingua = create(:arquivo, category: "artes", molde: molde, peca: lingua, arte: arte_lateral.arte)

      post adicionar_item_pedidos_path, params: { arquivo_uuid: arte_lateral.uuid, excluir_arquivos: [ arte_lingua.uuid ], grade: { "30" => "1" } }

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
      create(:item_pedido, :com_preco, pedido: pedido, arquivo: arte_a)
      create(:item_pedido, :com_preco, pedido: pedido, arquivo: arte_b)

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
      item_a = create(:item_pedido, :com_preco, pedido: pedido, arquivo: arte_a)
      create(:item_pedido_peca, item_pedido: item_a, arquivo: arte_a, incluida: false)
      create(:item_pedido, :com_preco, pedido: pedido, arquivo: arte_b)

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
      item = create(:item_pedido, :com_preco, pedido: pedido)
      create(:item_pedido_peca, item_pedido: item, incluida: false)
      post confirmar_pedido_path(pedido)
      expect(pedido.reload.status).to eq("confirmado")
    end

    it "confirms single-client pedido in-place without duplication" do
      client = create(:client)
      arte = create(:arquivo, category: "artes", client: client)
      pedido = create(:pedido)
      create(:item_pedido, :com_preco, pedido: pedido, arquivo: arte)

      expect {
        post confirmar_pedido_path(pedido)
      }.not_to change(Pedido, :count)

      pedido.reload
      expect(pedido.status).to eq("confirmado")
      expect(pedido.client_id).to eq(client.id)
    end

    # Etapa 2.4 (decided 09/10/2026): the price is written at confirmation —
    # a later change of the molde's price doesn't reach it — and travels to the
    # pedidos a split makes.
    it "writes each number's price per pair, also into the split pedidos" do
      pedido = create(:pedido)
      create(:item_pedido, :com_preco, pedido: pedido)
      create(:item_pedido, :com_preco, pedido: pedido)
      post confirmar_pedido_path(pedido)
      novos = ItemPedidoGrade.joins(item_pedido: :pedido).where(pedidos: { status: "confirmado" })
      expect(novos.pluck(:preco_par)).to eq([ 10, 10 ])
    end

    it "refuses to confirm a number without price per pair, naming the molde" do
      pedido = create(:pedido)
      item = create(:item_pedido, :com_preco, pedido: pedido)
      item.grades.create!(tamanho_nome: "47", quantidade: 1)
      post confirmar_pedido_path(pedido)
      expect(flash[:alert]).to include("Molde #{item.arquivo.molde.nome} sem preço por par para 47")
      expect(pedido.reload.status).to eq("rascunho")
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

    # Etapa 1.2 (3/3): a part without file can be left out too (its numbers
    # then stop blocking).
    it "checks and unchecks a part the arte has no file for" do
      sem_arquivo = create(:item_pedido_peca, item_pedido: item, arquivo: nil)
      alternar("false", row: sem_arquivo)
      expect([ response.parsed_body["ok"], sem_arquivo.reload.incluida ]).to eq([ true, false ])
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

  describe "GET /pedidos/:uuid item matrix" do
    let(:pedido) { create(:pedido) }
    let(:item) { create(:item_pedido, pedido: pedido) }

    # Etapa 1.2 (3/3, parte 3a): the item is a matrix — a column per number,
    # a row per part with where each number comes from.
    it "shows the matrix: per part its state and checkbox, per number its quantity, DXF size and file" do
      lateral, lingua = create(:peca, nome: "Lateral"), create(:peca, nome: "Língua")
      outro = item_com_dxf(pedido: pedido, grade: { "29" => 4, "30" => 6, "31" => 2 }, partes: [ lateral, lingua ])
      outro.item_pedido_pecas.find_by(peca: lingua).update!(incluida: false)
      get pedido_path(pedido)
      html = Nokogiri::HTML(response.body)
      partes = html.css(".pedido-item .pedido-peca")
      expect(partes.map { |c| c.css(".pedido-peca-nome").text }).to eq(%w[Lateral Língua])
      expect(partes.map { |c| c[:class].split.include?("pedido-peca--excluida") }).to eq([ false, true ])
      expect(partes.map { |c| c.css("input.pedido-peca-check").size }).to eq([ 1, 1 ])

      linha = outro.item_pedido_pecas.find_by(peca: lateral).uuid
      celula = ->(numero) { html.at_css(".pedido-parte-numero[data-peca-uuid='#{linha}'][data-numero='#{numero}']") }
      expect(%w[29 30 31 32].map { |n| celula.(n)["data-estado"] }).to eq(%w[producao producao sem_arquivo livre])
      expect([ celula.("29").at_css("a")["title"], celula.("31").text.squish ]).to eq([ "arte-lateral", "31-32 sem arquivo" ])
      quantidades = html.css(".pedido-matriz-qtd input").to_h { |i| [ i["data-tamanho-nome"], i["value"] ] }
      expect(quantidades.values_at("29", "30", "31", "32")).to eq(%w[4 6 2 0])
    end

    # The product's grade is 18…46; only the DXF's numbers come shown, the
    # rest wait behind "+ 28" / "+ 33" (grade-matriz).
    it "hides the columns outside the molde's DXF numbers" do
      item_com_dxf(pedido: pedido, grade: { "30" => 1 })
      get pedido_path(pedido)
      numeros = Nokogiri::HTML(response.body).css(".pedido-matriz-numero")
      expect(numeros.reject { |n| n.key?("hidden") }.map(&:text)).to eq(%w[29 30 31 32])
      expect(numeros.map(&:text)).to eq((18..46).map(&:to_s))
    end

    it "lists a missing file in the side panel with what settles it" do
      outro = item_com_dxf(pedido: pedido, grade: { "31" => 2, "32" => 1 })
      get pedido_path(pedido)
      li = Nokogiri::HTML(response.body).at_css(".pedido-painel .pedido-pendencia--sem_arquivo")
      expect(li.at_css(".pedido-pendencia-texto").text).to start_with("Lateral 31-32 (31×2, 32×1) sem arquivo de produção")
      expect(li.at_css("form.pedido-parte-enviar")["action"]).to eq(acrescentar_arquivo_arte_path(outro.arquivo))
      expect(li.at_css("input[name='tamanho_uuid']")["value"]).to eq(Tamanho.find_by!(nome: "31-32").uuid)
      expect(li.at_css("a.pedido-parte-trazer")["href"]).to eq(arquivo_path(outro.arquivo, trazer: 1, anchor: "arte-arquivos"))
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

  # Etapa 1.2 (3/3, parte 3b, decided 06/10/2026): the factory's Corte page.
  describe "GET /pedidos/:uuid/corte" do
    let(:pedido) { create(:pedido) }
    let(:lateral) { create(:peca, nome: "Lateral") }
    let(:lingua) { create(:peca, nome: "Língua") }
    let!(:item) { item_com_dxf(pedido: pedido, grade: { "30" => 2, "31" => 1 }, partes: [ lateral, lingua ]) }

    it "lists per part × DXF size its drawing, the pieces (right / left when mirrored) and the DXF" do
      item.arquivo.molde.molde_pecas.find_by(peca: lateral).update!(espelhada: true)
      get corte_pedido_path(pedido)
      html = Nokogiri::HTML(response.body)
      linhas = html.css("tr.corte-linha").map { |tr| [ tr["data-peca"], tr["data-tamanho"], tr.css(".corte-total strong, .corte-total .corte-conta:not(.corte-metros)").map(&:text).join(" ").squish ] }
      expect(linhas).to eq([
        [ "Lateral", "29-30", "4 peças 2 direito · 2 esquerdo" ],
        [ "Lateral", "31-32", "2 peças 1 direito · 1 esquerdo" ],
        # The Língua has no DXF in this molde: what it misses, to resolve.
        [ "Língua", nil, "6 peças" ]
      ])
      tamanho = Tamanho.find_by!(nome: "29-30")
      linha = html.at_css("tr.corte-linha[data-tamanho='29-30']")
      expect([ linha.at_css("img.corte-previa")["src"], linha.at_css("a.corte-dxf")["href"] ]).to eq([ preview_tamanho_path(tamanho), download_tamanho_path(tamanho) ])
      expect(html.at_css("a.corte-zip")["href"]).to eq(baixar_corte_pedido_path(pedido))
    end

    it "is linked from the pedido page" do
      get resumo_pedido_path(pedido)
      expect(Nokogiri::HTML(response.body).at_css("a.pedido-ir-corte")["href"]).to eq(corte_pedido_path(pedido))
    end

    # Etapa 2.2 (1/3, decided 07/10/2026): the expected metragem comes from the
    # size's fit on the item's material's roll.
    it "shows each line's expected metragem on the item's material, and the total" do
      material = MateriaPrima.create!(grupo_material: GrupoMaterial.create!(nome: "Tactel"), cor_material: CorMaterial.create!(nome: "Azul"), largura: "1.40 m", gramatura: "80g")
      item.update!(materia_prima: material)
      Tamanho.find_by!(nome: "29-30").tap { |t| t.update!(metros_por_peca: { "1400" => 0.02 }) }.arquivo.update!(giro: "180")
      get corte_pedido_path(pedido)
      html = Nokogiri::HTML(response.body)
      expect(html.at_css("tr.corte-linha[data-tamanho='29-30'] .corte-metros").text.squish).to eq("≈ 0,08 m de tecido")
      expect(html.at_css("tr.corte-linha[data-tamanho='31-32'] .corte-metros").text.squish).to eq("metragem ainda não calculada")
      expect(html.at_css("[data-corte='metros']").text).to eq("≈ 0,08 m de tecido")
    end

    it "zips every size's DXF, named by part, size and corte" do
      corte = Tamanho.find_by!(nome: "29-30").arquivo
      version = create(:arquivo_version, arquivo: corte, approved: true, extension: "dxf", original_file: "corte.dxf")
      corte.update!(approved_version_id: version.id)
      FileUtils.mkdir_p(File.join(version.storage_dir, "original"))
      File.write(version.original_path, "ORIGINAL")
      corte.tamanhos.each do |t|
        FileUtils.mkdir_p(File.dirname(t.dxf_extraido_path(version)))
        File.write(t.dxf_extraido_path(version), "DXF #{t.nome}")
      end

      get baixar_corte_pedido_path(pedido)
      expect(response.headers["Content-Disposition"]).to include("Corte #{pedido.uuid.first(8)}.zip")
      lidos = Zip::File.open_buffer(StringIO.new(response.body)).entries.to_h { |e| [ e.name, e.get_input_stream.read ] }
      expect(lidos).to eq("Lateral 29-30 - 24 AO 34 - CABEDAL.dxf" => "DXF 29-30", "Lateral 31-32 - 24 AO 34 - CABEDAL.dxf" => "DXF 31-32")
    end

    it "goes back to the page, saying why, when a corte has no file" do
      get baixar_corte_pedido_path(pedido)
      expect(response).to redirect_to(corte_pedido_path(pedido))
      expect(flash[:alert]).to include("has no original file")
    end
  end

  # Etapa 1.2 (3/3, parte 3c, decided 06/10/2026): the printer's page.
  describe "GET /pedidos/:uuid/impressao" do
    let(:pedido) { create(:pedido) }
    let(:lateral) { create(:peca, nome: "Lateral") }
    let!(:item) { item_com_dxf(pedido: pedido, grade: { "30" => 2, "31" => 1 }, partes: [ lateral ]) }

    it "lists per arte each file to print, in pieces, and what is missing" do
      get impressao_pedido_path(pedido)
      linhas = Nokogiri::HTML(response.body).css("tr.impressao-linha").map { |tr| [ tr["data-tamanho"], tr["data-estado"], tr.at_css(".corte-total strong").text ] }
      expect(linhas).to eq([ [ "29-30", "producao", "4 peças" ], [ "31-32", "sem_arquivo", "2 peças" ] ])
      expect(Nokogiri::HTML(response.body).at_css("a.impressao-baixar")["href"]).to eq(download_arquivo_path(item.arquivo))
    end

    # Etapa 2.2 (1/3): the arte's rectangle on the paper's width.
    it "shows each line's expected paper from the file's size and the paper's width" do
      version = create(:arquivo_version, arquivo: item.arquivo, approved: true)
      ArquivoImageMetadata.create!(arquivo_version: version, width_px: 3000, height_px: 600, dpi: 300)
      item.arquivo.update!(approved_version_id: version.id)
      get impressao_pedido_path(pedido)
      # 254 × 50,8 mm, never turned: 6 across 1,60 m → 0,00847 m per piece × 4 pieces.
      expect(Nokogiri::HTML(response.body).at_css("tr.impressao-linha[data-tamanho='29-30'] .corte-metros").text.squish).to eq("≈ 0,03 m de papel")
    end

    it "is linked from the pedido page, next to the Corte" do
      get resumo_pedido_path(pedido)
      expect(Nokogiri::HTML(response.body).at_css("a.pedido-ir-impressao")["href"]).to eq(impressao_pedido_path(pedido))
    end

    it "lists a mirrored part's missing side, and the pedido sends that side" do
      item.arquivo.molde.molde_pecas.find_by(peca: lateral).update!(espelhada: true)
      item.arquivo.update!(lado: "esquerdo")
      get impressao_pedido_path(pedido)
      falta = Nokogiri::HTML(response.body).at_css("tr.impressao-linha[data-estado='sem_lado']")
      expect([ falta["data-lado"], falta.at_css(".corte-arquivo").text.squish ]).to eq([ "direito", "sem o arquivo DIR" ])

      get resumo_pedido_path(pedido)
      li = Nokogiri::HTML(response.body).at_css(".pedido-pendencia--sem_lado")
      expect([ li.at_css("input[name='lado']")["value"], li.at_css(".pedido-peca-enviar-label").text.squish ]).to eq([ "direito", "Enviar arquivo DIR" ])
    end

    it "zips the files to print under their full names" do
      version = create(:arquivo_version, arquivo: item.arquivo, approved: true, extension: "tif", original_file: "x.tif")
      item.arquivo.update!(approved_version_id: version.id)
      FileUtils.mkdir_p(File.dirname(version.original_path))
      File.write(version.original_path, "TIFF")

      get baixar_impressao_pedido_path(pedido)
      expect(response.headers["Content-Disposition"]).to include("Impressao #{pedido.uuid.first(8)}.zip")
      lidos = Zip::File.open_buffer(StringIO.new(response.body)).entries.to_h { |e| [ e.name, e.get_input_stream.read ] }
      expect(lidos).to eq("#{item.arquivo.nome_completo(para_arquivo: true)}.tif" => "TIFF")
    end

    it "goes back to the page, saying why, when a file is missing on disk" do
      version = create(:arquivo_version, arquivo: item.arquivo, approved: true, extension: "tif", original_file: "sumiu.tif")
      item.arquivo.update!(approved_version_id: version.id)
      get baixar_impressao_pedido_path(pedido)
      expect(response).to redirect_to(impressao_pedido_path(pedido))
      expect(flash[:alert]).to include("sumiu.tif")
    end
  end

  # Etapa 2.4 (decided 09/10/2026): price, cost and margin per pair.
  describe "the pedido's values" do
    it "shows each number's price, cost and margin per pair, and the totals" do
      Empresa.atual.update!(custo_impressao_metro: 10, custo_corte_peca: 1)
      pedido = create(:pedido)
      item = create(:item_pedido, :com_preco, pedido: pedido)
      item.item_pedido_pecas.create!(peca: create(:peca), position: 0)
      item.grades.find_by!(tamanho_nome: "30").update!(quantidade: 3)
      get pedido_path(pedido)
      html = Nokogiri::HTML(response.body)
      linha = html.at_css("#pedido-valores tr[data-numero='30']")
      # One part with no file yet: 2 pieces cut × R$ 1, printing unknown (*).
      expect(%w[preco custo margem].map { |c| linha.at_css("[data-coluna='#{c}']").text.squish }).to eq([ "R$ 10,00", "R$ 2,00*", "R$ 8,00" ])
      expect(%w[valor custo margem].map { |v| html.at_css("[data-valor='#{v}']").text }).to eq([ "R$ 30,00", "R$ 6,00", "R$ 24,00" ])
    end

    it "asks for the costs in Parâmetros while they aren't set" do
      pedido = create(:pedido)
      create(:item_pedido, :com_preco, pedido: pedido)
      get pedido_path(pedido)
      expect(Nokogiri::HTML(response.body).at_css("[data-valor='custo']").text).to eq("—")
      expect(response.body).to include("printing cost per meter")
    end
  end

  describe "pending pieces on the pedido pages" do
    let(:pedido) { create(:pedido) }

    before do
      item = create(:item_pedido, :com_preco, pedido: pedido)
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

    it "refuses to confirm while an ordered number has no file, listing it on the page with the arte" do
      pedido = create(:pedido)
      item = item_com_dxf(pedido: pedido, grade: { "31" => 1 })
      post confirmar_pedido_path(pedido)
      expect(pedido.reload.status).to eq("rascunho")
      expect(flash[:alert]).to include("Lateral 31-32 (31×1) sem arquivo de produção")
      get pedido_path(pedido)
      li = Nokogiri::HTML(response.body).at_css(".pedido-pendencia--sem_arquivo")
      expect(li.at_css("a.pedido-parte-trazer")["href"]).to start_with(arquivo_path(item.arquivo))
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
