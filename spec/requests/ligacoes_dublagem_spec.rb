require "rails_helper"
require_relative "../support/construcoes"

# Rede editável 2/2a (decided 09-10/11/2026, canvas "Rede editável — C"): one
# page per ligação — the form, where it is used, its histórico —, a new one
# from "+ Ligação", and the trash.
RSpec.describe "Ligações da rede de dublagens", type: :request do
  let(:oxford) { material_de_dublagem("Oxford") }
  let(:lona) { material_de_dublagem("Lona") }
  let(:filme) { material_de_dublagem("Filme", tipo: "filme", micras: 35) }
  let(:ligacao) { LigacaoDublagem.do_par(oxford.grupo_material, lona.grupo_material).sole }
  let(:grupo) { ->(nome) { GrupoMaterial.find_by!(nome: nome) } }

  it "shows the form, the construções that use it (in use, the network changed) and the histórico" do
    construcao = montar_construcao([ oxford, "trama" ], [ lona, filme ]).tap(&:save!)
    MovimentoEstoque.create!(materia_prima: construcao.materia_prima, tipo: "entrada", quantidade: 5, da_empresa: true)
    patch rede_ligacao_path(ligacao), params: { ligacao: { lado: "", dubla: "depois", a_confirmar: [ "" ], ligantes: [ { grupo_uuid: grupo.("Filme").uuid, micras: "35 ou mais" } ] } }
    expect(response).to redirect_to(rede_ligacao_path(ligacao))

    get rede_ligacao_path(ligacao)
    html = Nokogiri::HTML(response.body)
    expect(html.at_css("h2").text.squish).to eq("Oxford com Lona")
    expect(html.at_css("input[name='ligacao[dubla]'][value=depois]")["checked"]).not_to be_nil
    expect(html.at_css("input[name='ligacao[ligantes][][micras]']")["value"]).to eq("35 ou mais")
    expect(html.at_css("[data-uso]").text.squish).to include(construcao.nome, "em uso", "a rede mudou")
    expect(html.at_css("[data-historico]").text.squish).to include("#{@usuario_logado.nome} · dubla antes → depois; Tecido molha: Filme PU → os de cima; a confirmar: situações → nenhum")
    expect(html.at_css("dialog [data-aviso-uso]").text.squish).to include("1 construção usa esta ligação: #{construcao.nome} (em uso)")

    get edit_construcao_path(construcao)
    expect(Nokogiri::HTML(response.body).at_css("[data-rede-mudou]").text.squish).to include("a rede mudou: guardou dubla antes; a rede agora diz depois", "ver na rede")
    get construcoes_path
    expect(response.body).to include("a rede mudou")
  end

  it "creates a ligação from + Ligação, the group it came from picked first" do
    importar_rede_de_dublagens
    get new_rede_ligacao_path(grupo: grupo.("Lona").uuid)
    expect(Nokogiri::HTML(response.body).at_css("#ligacao_grupo_a_uuid option[selected]").text).to eq("Lona")

    post rede_ligacoes_path, params: { ligacao: { grupo_a_uuid: grupo.("Lona").uuid, grupo_b_uuid: grupo.("EVA").uuid, lado: "", dubla: "antes",
                                                  ligantes: [ { grupo_uuid: grupo.("Cola").uuid, micras: "" } ] } }
    nova = LigacaoDublagem.order(:id).last
    expect(response).to redirect_to(rede_ligacao_path(nova))
    expect([ nova.nome, nova.alteracoes.sole.texto ]).to eq([ "Lona com EVA", "criou" ])
    get rede_de_dublagens_path
    expect(Nokogiri::HTML(response.body).at_css(".rede-grupo[data-grupo=Lona] a[href='#{rede_ligacao_path(nova)}']").text).to eq("EVA")
  end

  it "refuses a save it can't read, showing what was typed and why" do
    importar_rede_de_dublagens
    patch rede_ligacao_path(ligacao), params: { ligacao: { dubla: "antes", ligantes: [ { grupo_uuid: grupo.("Filme").uuid, micras: "trinta" } ] } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("micras &quot;trinta&quot; de Filme")
    expect(Nokogiri::HTML(response.body).at_css("input[name='ligacao[ligantes][][micras]']")["value"]).to eq("trinta")
    expect(ligacao.reload.alteracoes).to be_empty
  end

  it "goes to the trash, leaves the network, opens read only and comes back from the Lixeira" do
    importar_rede_de_dublagens
    delete rede_ligacao_path(ligacao)
    expect(response).to redirect_to(rede_de_dublagens_path)
    expect(RedeDeDublagens.ligacao("Oxford", "Lona")).to be_nil

    get rede_ligacao_path(ligacao)
    html = Nokogiri::HTML(response.body)
    expect(html.at_css(".badge-excluido")).to be_present
    expect(html.at_css("fieldset.ligacao-campos")["disabled"]).not_to be_nil
    patch rede_ligacao_path(ligacao), params: { ligacao: { dubla: "depois" } }
    expect(ligacao.reload.dubla).to eq("antes")

    get lixeira_path
    expect(Nokogiri::HTML(response.body).at_css("[data-tipo=ligacoes_dublagem]").text).to include("Oxford com Lona")
    post restaurar_lixeira_path(tipo: "ligacoes_dublagem", id: ligacao.uuid)
    expect(ligacao.reload).not_to be_excluido
    expect(ligacao.alteracoes.map(&:texto)).to eq([ "restaurou", "mandou para a lixeira" ])
  end

  it "is the team's only", sem_login: true do
    importar_rede_de_dublagens
    funcao = create(:funcao, :para_cliente, niveis: { "estoque" => 1 })
    entrar_como(create(:vinculo, user: create(:user), client: create(:client), funcao: funcao).user)

    get rede_ligacao_path(ligacao)
    expect(response).to have_http_status(:forbidden)
  end
end
