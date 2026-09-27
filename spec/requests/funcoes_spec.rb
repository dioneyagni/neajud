require "rails_helper"

RSpec.describe "Funções", type: :request do
  before { Funcao.criar_padrao! }

  it "shows the grid with every área, action and função" do
    get funcoes_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Catálogo", "Lixeira", "Baixar arquivos de produção", "Designer", "Restaurar")
  end

  it "creates a função with nothing allowed" do
    post funcoes_path, params: { funcao: { nome: "Expedição" } }
    expect(Funcao.find_by(nome: "Expedição")).to have_attributes(niveis: {}, acoes: [])
    expect(flash[:notice]).to include("Expedição")
  end

  it "refuses a repeated name" do
    post funcoes_path, params: { funcao: { nome: "designer" } }
    expect(flash[:alert]).to include("Nome")
  end

  it "saves the grid" do
    designer = Funcao.find_by!(nome: "Designer")
    patch atualizar_funcoes_path, params: { funcoes: { designer.uuid => { nome: "Designer", niveis: { lixeira: "2" }, acoes: [ "" ] } } }
    expect(designer.reload.niveis).to eq("lixeira" => 2)
    expect(designer.acoes).to eq([])
  end

  it "moves an unused função to the trash, refuses one in use" do
    em_uso = create(:vinculo, funcao: Funcao.find_by!(nome: "Produção")).funcao
    livre = Funcao.find_by!(nome: "Atendimento")
    delete funcao_path(em_uso)
    expect(flash[:alert]).to include("used by 1 user")
    delete funcao_path(livre)
    expect(livre.reload).to be_excluido
  end
end
