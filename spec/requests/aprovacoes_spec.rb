require "rails_helper"

RSpec.describe "Aprovações de arte", type: :request do
  let(:arte) do
    create(:arquivo, category: "artes", filename: "lateral-azul").tap do |a|
      a.update!(approved_version: create(:arquivo_version, arquivo: a, version_number: 1, status: :processed, approved: true))
    end
  end

  after { FileUtils.rm_rf(File.join(ArquivoVersion::STORAGE_BASE, arte.uuid)) }

  it "the arte page shows the state and the Register approval button" do
    get arquivo_path(arte)
    expect(response.body).to include("Client approval", "Aguardando aprovação", "Register approval")
  end

  it "registers from the form and returns to where it came from" do
    pedido = create(:pedido)
    get new_arquivo_aprovacao_path(arte, voltar_para: resumo_pedido_path(pedido))
    expect(response.body).to include("lateral-azul", "v1", "WhatsApp")
    post arquivo_aprovacoes_path(arte), params: { voltar_para: resumo_pedido_path(pedido), aprovacao: { canal: "email", aprovado_em: "2026-09-20" } }
    expect(response).to redirect_to(resumo_pedido_path(pedido))
    expect(arte.reload.estado_aprovacao).to eq(:aprovada)
    expect(arte.aprovacao_vigente.user).to eq(@usuario_logado)
  end

  # voltar_para comes from the URL: it must never send the user to another site.
  it "ignores a voltar_para of another host" do
    post arquivo_aprovacoes_path(arte), params: { voltar_para: "https://evil.example/x", aprovacao: { canal: "email", aprovado_em: "2026-09-20" } }
    expect(response).to redirect_to(arquivo_path(arte))
  end

  it "shows the form again with the errors" do
    post arquivo_aprovacoes_path(arte), params: { aprovacao: { canal: "outro", aprovado_em: "2026-09-20" } }
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("required when the channel is Outro")
  end

  it "cancels, keeping the history; downloads the attachment as a file" do
    pdf = Tempfile.new([ "zap", ".pdf" ]).tap { |f| f.write("%PDF-1.4"); f.rewind }
    aprovacao = RegistrarAprovacaoService.call(arte, user: @usuario_logado, dados: { canal: "whatsapp" },
                                              anexo: Rack::Test::UploadedFile.new(pdf.path, "application/pdf", original_filename: "zap.pdf"))
    get anexo_aprovacao_path(aprovacao)
    expect(response.headers["Content-Disposition"]).to include("attachment", "zap.pdf")
    post cancelar_aprovacao_path(aprovacao)
    expect(aprovacao.reload).to be_cancelada
    get arquivo_path(arte)
    expect(response.body).to include("cancelled by #{@usuario_logado.nome}", "Aguardando aprovação")
  end

  it "the pedido shows a badge per piece arte, and Confirmado sem aprovação once confirmed" do
    pedido = create(:pedido)
    item = create(:item_pedido, pedido: pedido, arquivo: arte)
    create(:item_pedido_peca, item_pedido: item, peca: create(:peca), arquivo: arte)
    get resumo_pedido_path(pedido)
    expect(response.body).to include("Aguardando aprovação", "Registrar aprovação")
    pedido.update_columns(status: "confirmado")
    get resumo_pedido_path(pedido)
    expect(response.body).to include("Confirmado sem aprovação")
  end

  it "the version in use is labelled Em uso, not Approved" do
    create(:arquivo_version, arquivo: arte, version_number: 2, status: :processed)
    get arquivo_path(arte)
    expect(response.body).to include("Usar esta versão", "Em uso")
    expect(response.body).not_to include(">Approve<", ">Approved<")
  end

  describe "permissions", sem_login: true do
    it "registering needs the aprovar_arte action" do
      entrar_com_funcao(niveis: { "artes" => 3 })
      get new_arquivo_aprovacao_path(arte)
      expect(response).to have_http_status(:forbidden)
      get arquivo_path(arte)
      expect(response.body).not_to include("Register approval")
    end
  end
end
