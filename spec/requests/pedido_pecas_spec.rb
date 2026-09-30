require "rails_helper"

RSpec.describe "PedidoPecas", type: :request do
  let(:client) { create(:client) }
  let(:lingua) { create(:peca, nome: "Língua") }
  let(:molde) { create(:molde, client: client, nome: "Tênis baixo") }
  let(:pedido) { create(:pedido) }
  let(:item) { create(:item_pedido, pedido: pedido, arquivo: create(:arquivo, client: client, molde: molde)) }
  let!(:pending_row) { create(:item_pedido_peca, item_pedido: item, peca: lingua, arquivo: nil) }

  describe "GET escolher_arte" do
    it "lists the candidate groups; artes from another molde ask to confirm the move" do
      free = create(:arquivo, client: client, filename: "livre")
      other = create(:arquivo, client: client, molde: create(:molde, client: client, nome: "Outro"), filename: "de-outro")
      get escolher_arte_pedido_peca_path(pedido, pending_row)
      html = Nokogiri::HTML(response.body)
      expect(html.css(".escolher-arte-grupo").map { |g| g["data-grupo"] }).to eq(%w[cliente_sem_peca cliente_sem_molde sem_cliente])
      move_form = html.at_css(".escolher-arte-card[data-arquivo-uuid='#{other.uuid}'] form")
      expect(move_form.at_css("input[name='confirmar_mudanca'][value='1']")).to be_present
      expect(move_form.at_css("button")["data-turbo-confirm"]).to include("Outro", "Tênis baixo")
      free_form = html.at_css(".escolher-arte-card[data-arquivo-uuid='#{free.uuid}'] form")
      expect(free_form.at_css("input[name='confirmar_mudanca']")).to be_nil
    end

    it "redirects when the pedido is no longer a draft" do
      pedido.update!(status: "confirmado")
      get escolher_arte_pedido_peca_path(pedido, pending_row)
      expect(response).to redirect_to(resumo_pedido_path(pedido))
    end

    it "returns 404 for a piece of another pedido" do
      other_row = create(:item_pedido_peca, arquivo: nil)
      get escolher_arte_pedido_peca_path(pedido, other_row)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST vincular_arte" do
    it "links the arte and returns to the pedido" do
      arte = create(:arquivo, client: client)
      post vincular_arte_pedido_peca_path(pedido, pending_row), params: { arquivo_uuid: arte.uuid }
      expect(response).to redirect_to(resumo_pedido_path(pedido))
      expect(flash[:notice]).to include(arte.filename, "Língua")
      expect(pending_row.reload.arquivo).to eq(arte)
    end

    it "sends a move back to the picker without the confirmation, changing nothing" do
      arte = create(:arquivo, client: client, molde: create(:molde, client: client, nome: "Outro"))
      post vincular_arte_pedido_peca_path(pedido, pending_row), params: { arquivo_uuid: arte.uuid }
      expect(response).to redirect_to(escolher_arte_pedido_peca_path(pedido, pending_row))
      expect(flash[:alert]).to include("confirm")
      expect(pending_row.reload.arquivo).to be_nil
    end

    it "moves and logs with the confirmation" do
      arte = create(:arquivo, client: client, molde: create(:molde, client: client, nome: "Outro"))
      post vincular_arte_pedido_peca_path(pedido, pending_row), params: { arquivo_uuid: arte.uuid, confirmar_mudanca: "1" }
      expect(arte.reload.molde).to eq(molde)
      expect(arte.vinculo_logs.sole.from_molde_nome).to eq("Outro")
    end
  end

  describe "pending card and arte history" do
    it "offers 'Escolher arte' on a pending piece of a draft pedido only" do
      get pedido_path(pedido)
      expect(Nokogiri::HTML(response.body).at_css("a.pedido-peca-escolher")["href"]).to eq(escolher_arte_pedido_peca_path(pedido, pending_row))
      pedido.update!(status: "confirmado")
      get pedido_path(pedido)
      expect(Nokogiri::HTML(response.body).at_css("a.pedido-peca-escolher")).to be_nil
    end

    it "shows the link history on the arte page, marking moves" do
      arte = create(:arquivo, client: client, molde: create(:molde, client: client, nome: "Outro"))
      VincularArteService.call(pending_row, arte, changed_by: "10.0.0.1", confirmar_mudanca: true)
      get arquivo_path(arte)
      row = Nokogiri::HTML(response.body).at_css("#vinculo-history-section tbody tr")
      expect(row["class"]).to include("vinculo-history-mudanca")
      expect(row.css("td").first(4).map(&:text).map(&:strip)).to eq([ "Outro", "Tênis baixo", "Língua", pedido.uuid.first(8) ])
    end

    it "hides the history section when there is none" do
      get arquivo_path(create(:arquivo))
      expect(Nokogiri::HTML(response.body).at_css("#vinculo-history-section")).to be_nil
    end
  end

  describe "POST enviar_arte" do
    let(:tif) { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/02-no_spot.tif"), "image/tiff") }

    after { Arquivo.where(filename: "02-no_spot").find_each { |a| FileUtils.rm_rf(File.join(ArquivoVersion::STORAGE_BASE, a.uuid)) } }

    it "creates the arte with the molde's client, links it to the piece and returns to the pedido" do
      expect { post enviar_arte_pedido_peca_path(pedido, pending_row), params: { original_file: tif } }.to change(Arquivo, :count).by(1)
      arte = Arquivo.find_by!(filename: "02-no_spot")
      expect([ arte.client, arte.molde, arte.peca, arte.category ]).to eq([ client, molde, lingua, "artes" ])
      expect(pending_row.reload.arquivo).to eq(arte)
      expect(arte.vinculo_logs.sole.to_molde_nome).to eq("Tênis baixo")
      expect(arte.vinculo_logs.sole.user).to eq(@usuario_logado)
      expect(response).to redirect_to(resumo_pedido_path(pedido))
      expect(flash[:notice]).to include("02-no_spot", "Língua")
    end

    it "fills the same pending piece in other draft pedidos too" do
      other_item = create(:item_pedido, pedido: create(:pedido), arquivo: create(:arquivo, client: client, molde: molde))
      other_row = create(:item_pedido_peca, item_pedido: other_item, peca: lingua, arquivo: nil)
      post enviar_arte_pedido_peca_path(pedido, pending_row), params: { original_file: tif }
      expect(other_row.reload.arquivo&.filename).to eq("02-no_spot")
    end

    it "refuses a non-arte file (e.g. a DXF corte) without creating anything" do
      dxf = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/29-30.dxf"), "image/vnd.dxf")
      expect { post enviar_arte_pedido_peca_path(pedido, pending_row), params: { original_file: dxf } }.not_to change(Arquivo, :count)
      expect(flash[:alert]).to include("29-30.dxf is not an arte file", "tif")
      expect(pending_row.reload.arquivo).to be_nil
    end

    it "asks for a file when none was sent" do
      post enviar_arte_pedido_peca_path(pedido, pending_row)
      expect(flash[:alert]).to eq("Select a file to upload.")
    end

    it "reports upload validation errors without linking" do
      path = Rails.root.join("tmp/enviar-fake.tif").to_s
      system("convert", "-size", "10x10", "xc:red", "PNG:#{path}", exception: true)
      post enviar_arte_pedido_peca_path(pedido, pending_row), params: { original_file: Rack::Test::UploadedFile.new(path, "image/tiff") }
      expect(flash[:alert]).to include("Upload failed", "declared 'TIF' but file is 'PNG'")
      expect(pending_row.reload.arquivo).to be_nil
    ensure
      FileUtils.rm_f(path)
    end

    it "offers the upload on a pending piece of a draft pedido" do
      get pedido_path(pedido)
      form = Nokogiri::HTML(response.body).at_css("form.pedido-peca-enviar")
      expect(form["action"]).to eq(enviar_arte_pedido_peca_path(pedido, pending_row))
      expect(form["enctype"]).to eq("multipart/form-data")
      expect(form.at_css("input[type=file]")["accept"]).to include(".tif", ".psd")
    end
  end
end
