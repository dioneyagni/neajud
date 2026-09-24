require "rails_helper"

RSpec.describe "PedidoPecas", type: :request do
  let(:client) { create(:client) }
  let(:lingua) { create(:peca, nome: "Língua") }
  let(:modelo) { create(:modelo, client: client, nome: "Tênis baixo") }
  let(:pedido) { create(:pedido) }
  let(:item) { create(:item_pedido, pedido: pedido, arquivo: create(:arquivo, client: client, modelo: modelo)) }
  let!(:pending_row) { create(:item_pedido_peca, item_pedido: item, peca: lingua, arquivo: nil) }

  describe "GET escolher_arte" do
    it "lists the candidate groups; artes from another modelo ask to confirm the move" do
      free = create(:arquivo, client: client, filename: "livre")
      other = create(:arquivo, client: client, modelo: create(:modelo, client: client, nome: "Outro"), filename: "de-outro")
      get escolher_arte_pedido_peca_path(pedido, pending_row)
      html = Nokogiri::HTML(response.body)
      expect(html.css(".escolher-arte-grupo").map { |g| g["data-grupo"] }).to eq(%w[cliente_sem_peca cliente_sem_modelo sem_cliente])
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
      arte = create(:arquivo, client: client, modelo: create(:modelo, client: client, nome: "Outro"))
      post vincular_arte_pedido_peca_path(pedido, pending_row), params: { arquivo_uuid: arte.uuid }
      expect(response).to redirect_to(escolher_arte_pedido_peca_path(pedido, pending_row))
      expect(flash[:alert]).to include("confirm")
      expect(pending_row.reload.arquivo).to be_nil
    end

    it "moves and logs with the confirmation" do
      arte = create(:arquivo, client: client, modelo: create(:modelo, client: client, nome: "Outro"))
      post vincular_arte_pedido_peca_path(pedido, pending_row), params: { arquivo_uuid: arte.uuid, confirmar_mudanca: "1" }
      expect(arte.reload.modelo).to eq(modelo)
      expect(arte.vinculo_logs.sole.from_modelo_nome).to eq("Outro")
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
      arte = create(:arquivo, client: client, modelo: create(:modelo, client: client, nome: "Outro"))
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
end
