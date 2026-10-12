require "rails_helper"

# Etapa 2.8 (4a, decided 12/10/2026): the cliente final answers a request for
# approval on the arte's page — approves the versions he picks, or asks for
# changes — and the team sees the answer there.
RSpec.describe "A cliente final answers an approval", type: :request do
  let(:client) { create(:client) }
  let(:equipe) { @usuario_logado }
  let(:arte) do
    create(:arquivo, client: client, filename: "arte-bia").tap do |a|
      2.times { |n| a.update!(approved_version: create(:arquivo_version, arquivo: a, version_number: n + 1, status: :processed)) }
      SolicitacaoAprovacao.create!(arquivo: a, arquivo_version: a.approved_version, user: create(:user))
    end
  end
  let(:v1) { arte.arquivo_versions.find_by(version_number: 1) }

  def entrar_como_cliente_final
    funcao = create(:funcao, :para_cliente, niveis: { "artes" => 1 }, acoes: %w[aprovar_arte])
    entrar_como(create(:vinculo, user: create(:user, nome: "Bia"), client: client, funcao: funcao).user)
  end

  it "shows him the versions to pick and the note, never the team's buttons" do
    entrar_como_cliente_final
    get arquivo_path(arte)
    html = Nokogiri::HTML(response.body)
    expect(html.css("#resposta-do-cliente select[name='versoes[#{arte.uuid}]'] option").map(&:text)).to eq([ "v2 (in use)", "v1" ])
    expect(response.body).not_to include("Register approval", "Cancel request")
  end

  it "approving the version in use approves the arte" do
    entrar_como_cliente_final
    post arquivo_aprovar_no_sistema_path(arte)
    expect(response).to redirect_to(arquivo_path(arte))
    expect(arte.estado_aprovacao).to eq(:aprovada)
    expect(arte.aprovacao_vigente).to have_attributes(canal: "sistema")
  end

  it "approving another version leaves the team the switch, which approves it" do
    entrar_como_cliente_final
    post arquivo_aprovar_no_sistema_path(arte), params: { versoes: { arte.uuid => v1.uuid } }
    expect(arte.estado_aprovacao).to eq(:aprovada_em_outra_versao)

    entrar_como(equipe)
    get arquivo_path(arte)
    expect(Nokogiri::HTML(response.body).at_css("#aprovacao-outra-versao li").text).to include("the client approved v1", "(in use v2)")
    patch approve_version_arquivo_path(arte, version_uuid: v1.uuid)
    expect(arte.reload.estado_aprovacao).to eq(:aprovada)
  end

  it "asking for changes shows the team his note and lets it send again" do
    entrar_como_cliente_final
    post arquivo_pedir_alteracao_path(arte), params: { recado: "Azul mais escuro" }
    expect(arte.estado_aprovacao).to eq(:alteracao_pedida)

    entrar_como(equipe)
    get arquivo_path(arte)
    expect(Nokogiri::HTML(response.body).at_css("#alteracao-pedida").text).to include("Bia", "Azul mais escuro")
    post arquivo_solicitacoes_path(arte)
    expect(arte.estado_aprovacao).to eq(:aguardando)
  end

  # Another client's arte is a 404 like any record he doesn't see (Visibilidade).
  it "can't answer another client's arte" do
    outra = create(:arquivo, client: create(:client))
    entrar_como_cliente_final
    post arquivo_aprovar_no_sistema_path(outra)
    expect(response).to have_http_status(:not_found)
  end
end
