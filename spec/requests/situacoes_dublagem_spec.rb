require "rails_helper"
require_relative "../support/construcoes"

# Rede editável 2/2b (decided 10/11/2026, canvas "2/2b · Rede: bloco
# Situações"): the rede's Situações card — the list with what each changes,
# "+ Situação", renaming, the histórico; and the construção's note for a
# situação no ligação lists (Q3a).
RSpec.describe "Situações da rede de dublagens", type: :request do
  before { importar_rede_de_dublagens }

  let(:cartao) { -> { get rede_de_dublagens_path; Nokogiri::HTML(response.body).at_css("#situacoes") } }

  it "lists each situação with the ligações it changes and the construções that have it" do
    linha = cartao.().at_css("[data-situacao-linha=tecido_molha]")
    expect(linha.at_css("[data-nome]").text).to eq("Tecido molha")
    expect(linha.at_css("[data-uso]").text.squish).to match(/\Amuda \d+ ligaç(ão|ões) · 0 construções\z/)
  end

  it "adds a situação that changes nothing yet, with its column, its line and the construção's note" do
    post rede_situacoes_path, params: { situacao: { nome: "Tecido úmido" } }
    expect(response).to redirect_to(rede_de_dublagens_path(anchor: "situacoes"))
    expect(flash[:notice]).to eq("Situação Tecido úmido: criada.")

    html = cartao.()
    expect(html.at_css("[data-situacao-linha=tecido_umido] [data-uso]").text.squish).to eq("ainda não muda nenhuma ligação · 0 construções")
    expect(html.at_css("[data-historico]").text.squish).to include("#{@usuario_logado.nome} · criou Tecido úmido")
    expect(response.body).to include("<th>Tecido úmido</th>")

    get new_construcao_path
    nota = Nokogiri::HTML(response.body).at_css("input[name='construcao[situacao]'][value=tecido_umido]").parent.at_css("[data-nao-muda]")
    expect(nota.text).to eq("ainda não muda nenhuma ligação")
  end

  it "refuses a repeated name, saying which" do
    post rede_situacoes_path, params: { situacao: { nome: "tecido MOLHA" } }
    expect(flash[:alert]).to eq("Situação \"tecido MOLHA\": Nome tecido MOLHA já é uma situação da rede")
    expect(SituacaoDublagem.count).to eq(2)
  end

  it "renames one, keeping its chave" do
    situacao = SituacaoDublagem.find_by!(chave: "tecido_molha")
    patch rede_situacao_path(situacao), params: { situacao: { nome: "Tecido encharcado" } }
    expect(flash[:notice]).to eq("Situação Tecido encharcado: salva.")
    expect(situacao.reload.slice(:chave, :nome).values).to eq([ "tecido_molha", "Tecido encharcado" ])
    expect(cartao.().at_css("[data-historico]").text).to include("renomeou Tecido molha → Tecido encharcado")
  end

  it "shows the card read only without the action" do
    entrar_com_funcao(niveis: { "estoque" => 3 }, acoes: Autorizacao::ACOES - %w[editar_rede_de_dublagens])
    html = cartao.()
    expect(html.css("[data-situacao-linha]").size).to eq(2)
    expect(html.css("form, button")).to be_empty
  end
end
