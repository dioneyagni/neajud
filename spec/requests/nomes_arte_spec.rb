require "rails_helper"

# Etapa 1.1 (5/5): an arte's Referência + Nome, and joining an arte uploaded twice.
RSpec.describe "Nomes de arte", type: :request do
  let(:molde) { create(:molde, modelo: create(:modelo, abreviacao: "TNS")) }
  let(:tamanho) { create(:tamanho, nome: "29-30") }
  let(:arte) { create(:arquivo, category: "artes", molde: molde, tamanho: tamanho) }

  describe "PATCH /arquivos/:uuid/nome_arte" do
    it "saves a referência chosen in the molde and the name" do
      dezenove = create(:referencia, molde: molde, nome: "19")
      patch arquivo_nome_arte_path(arte), params: { referencia_uuid: dezenove.uuid, nome: " Bluey  Azul " }
      expect([ arte.reload.referencia, arte.nome ]).to eq([ dezenove, "Bluey Azul" ])
      expect(flash[:notice]).to include("001-TNS_19_Bluey Azul")
    end

    it "creates a new referência in the molde, reusing one with the same comparable name" do
      elite = create(:referencia, molde: molde, nome: "Élite")
      expect { patch arquivo_nome_arte_path(arte), params: { nova_referencia: "Fuel", nome: "X" } }.to change(molde.referencias, :count).by(1)
      patch arquivo_nome_arte_path(arte), params: { nova_referencia: "elite", nome: "X" }
      expect(arte.reload.referencia).to eq(elite)
    end

    it "refuses a referência of another molde (404, not linked)" do
      outra = create(:referencia, molde: create(:molde), nome: "20")
      patch arquivo_nome_arte_path(arte), params: { referencia_uuid: outra.uuid, nome: "X" }
      expect(response).to have_http_status(:not_found)
      expect(arte.reload.referencia).to be_nil
    end

    # Cortes have no Referência/Nome; the route only answers for artes.
    it "doesn't exist for a corte" do
      corte = create(:arquivo, :corte)
      patch arquivo_nome_arte_path(corte), params: { nome: "X" }
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the arte page" do
    it "shows the full name and, on the newer of two repeats, the button to join them" do
      ref = create(:referencia, molde: molde, nome: "19")
      primeira = create(:arquivo, category: "artes", molde: molde, tamanho: tamanho, referencia: ref, nome: "Bluey", filename: "primeira", created_at: 1.hour.ago)
      segunda = create(:arquivo, category: "artes", molde: molde, tamanho: tamanho, referencia: ref, nome: "BLUEY", filename: "segunda")

      get arquivo_path(segunda)
      expect(response.body).to include("001-TNS_19_BLUEY", "Make it a new version of that arte")
      get arquivo_path(primeira)
      expect(response.body).to include("A newer file has the same full name")
      expect(response.body).not_to include("Make it a new version")
    end
  end

  describe "POST /arquivos/:uuid/nome_arte/tornar_versao" do
    it "explains a refusal on the arte's page" do
      outra = create(:arquivo, category: "artes", molde: molde, tamanho: tamanho, nome: "Outra")
      arte.update!(nome: "Esta")
      post tornar_versao_arquivo_nome_arte_path(arte), params: { original_uuid: outra.uuid }
      expect(response).to redirect_to(arquivo_path(arte))
      expect(flash[:alert]).to include("are not the same full name")
    end
  end
end
