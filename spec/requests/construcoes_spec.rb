require "rails_helper"
require_relative "../support/construcoes"

# Dublagem 3/5 (decided 30/10-02/11/2026): the construções' list and form.
RSpec.describe "Construções", type: :request do
  let!(:oxford) { material_de_dublagem("Oxford", cor: "Preto", preco: 20) }
  let!(:lona) { material_de_dublagem("Lona", preco: 10) }
  let!(:filme_35) { material_de_dublagem("Filme", tipo: "filme", micras: 35, preco: 3) }

  def html = Nokogiri::HTML(response.body)

  def camadas(*linhas)
    linhas.each_with_index.to_h { |linha, indice| [ indice.to_s, linha ] }
  end

  def formulario(*linhas, **campos)
    { construcao: { situacao: "", client_uuid: "", preco_final: "", camadas: camadas(*linhas) }.merge(campos) }
  end

  def opcoes(seletor) = html.css("#{seletor} option").map(&:text).reject { |texto| texto.start_with?("—") }

  it "opens the new form with the superfícies and the price card" do
    get new_construcao_path

    expect(response).to have_http_status(:ok)
    expect(opcoes("#camada-0-material")).to eq([ oxford.nome_completo ])
    expect(html.css('input[name="construcao[situacao]"]').map { |radio| radio["value"] }).to eq([ "", "vai_frequencia", "tecido_molha" ])
    expect(html.at_css("[data-sugerido]").text).to eq("$0.00")
  end

  # Each change asks montar for the form again, nothing saved.
  it "rebuilds the form with the bases that dub, the ligantes the network allows and the price" do
    material_de_dublagem("Helanca")
    Empresa.atual.update!(preco_servico_dublagem: 4)
    linhas = [ { materia_prima_uuid: oxford.uuid, lado: "trama", do_cliente: "0" }, { materia_prima_uuid: lona.uuid, do_cliente: "0", ligante_uuid: filme_35.uuid } ]

    expect { post montar_construcoes_path, params: formulario(*linhas), as: :turbo_stream }.not_to change(Construcao, :count)

    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(opcoes("#camada-1-material")).to contain_exactly(oxford.nome_completo, lona.nome_completo)
    expect(opcoes(".construcao-ligante")).to eq([ filme_35.nome_completo ])
    expect(html.at_css("[data-ligacao]").text.squish).to include("dubla antes da estampa", "a confirmar")
    expect(html.at_css("[data-sugerido]").text).to eq("$37.00")
  end

  it "adds and removes a layer on montar" do
    linhas = [ { materia_prima_uuid: oxford.uuid, lado: "trama" }, { materia_prima_uuid: lona.uuid, ligante_uuid: filme_35.uuid } ]

    post montar_construcoes_path, params: formulario(*linhas).merge(acao: "adicionar"), as: :turbo_stream
    expect(html.css(".construcao-item").size).to eq(3)

    post montar_construcoes_path, params: formulario(*linhas, { materia_prima_uuid: "" }).merge(acao: "remover-2"), as: :turbo_stream
    expect(html.css(".construcao-item").size).to eq(2)
    expect(html.at_css("[data-problemas]").text).to include("camada 2: escolha o material")
  end

  it "saves a construção and its dublado" do
    post construcoes_path, params: formulario({ materia_prima_uuid: oxford.uuid, lado: "trama" }, { materia_prima_uuid: lona.uuid, ligante_uuid: filme_35.uuid }, preco_final: "46,50")

    construcao = Construcao.last
    expect(response).to redirect_to(edit_construcao_path(construcao))
    expect(construcao.materia_prima).to have_attributes(tipo: "dublado", preco_metro: 46.5)
    expect(construcao.camadas.map { |camada| [ camada.posicao, camada.materia_prima, camada.ligante ] }).to eq([ [ 1, oxford, nil ], [ 2, lona, filme_35 ] ])
  end

  it "answers what is wrong, keeping the form" do
    helanca = material_de_dublagem("Helanca")

    post construcoes_path, params: formulario({ materia_prima_uuid: oxford.uuid, lado: "trama" }, { materia_prima_uuid: helanca.uuid })

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("camada 2: Oxford e Helanca não dublam — a rede não tem essa ligação")
    expect(html.at_css("#camada-1-material option[selected]").text).to eq(helanca.nome_completo)
    # Never the uuid of the construção that wasn't saved: montar would answer 404.
    expect(html.at_css("form.construcao-form")["data-construcao-uuid-value"]).to eq("")
  end

  # Decision 5: in use, only the final price changes.
  it "changes only the final price of a construção in use" do
    construcao = montar_construcao([ oxford, "trama" ], [ lona, filme_35 ]).tap(&:save!)
    MovimentoEstoque.create!(materia_prima: construcao.materia_prima, tipo: "entrada", quantidade: 5, da_empresa: true)

    get edit_construcao_path(construcao)
    expect(html.at_css("[data-em-uso]")).to be_present
    expect(html.at_css("#camada-0-material")["disabled"]).to be_present

    patch construcao_path(construcao), params: formulario({ materia_prima_uuid: lona.uuid }, preco_final: "50")
    expect(construcao.reload.camadas.first.materia_prima).to eq(oxford)
    expect(construcao.materia_prima.preco_metro).to eq(50)
  end

  it "lists the construções with whose each is and the prices, and trashes one" do
    construcao = montar_construcao([ oxford, "trama", { do_cliente: true } ], [ lona, filme_35 ], client: create(:client, name: "Fagner"), preco_final: 40).tap(&:save!)

    get construcoes_path
    linha = html.at_css(".construcoes-item")
    expect(linha.text.squish).to include(construcao.nome, "Fagner", "Normal", "$13.00", "$40.00")

    delete construcao_path(construcao)
    expect(construcao.reload).to be_excluido
    get lixeira_path
    expect(html.at_css('.lixeira-grupo[data-tipo="construcoes"]').text).to include(construcao.nome)
  end

  # The ligante is the factory's (plano Etapa 2.9): as the rede, the team's only.
  it "is the team's only", sem_login: true do
    funcao = create(:funcao, :para_cliente, niveis: { "estoque" => 1 })
    entrar_como(create(:vinculo, user: create(:user), client: create(:client), funcao: funcao).user)

    get construcoes_path
    expect(response).to have_http_status(:forbidden)
    get materiais_path
    expect(html.at_css("a.materiais-construcoes-link")).to be_nil
  end

  # Decision 1: a dublado's type and price are its construção's.
  it "shows a dublado on Materiais with its construção, never as an editable material" do
    construcao = montar_construcao([ oxford, "trama" ], [ lona, filme_35 ], preco_final: 46).tap(&:save!)

    get materiais_path
    linha = html.at_css(%([data-material="#{construcao.materia_prima.uuid}"]))
    expect(linha.text.squish).to include(construcao.nome, "Dublado")
    expect(linha.at_css("a.material-construcao-link")["href"]).to eq(edit_construcao_path(construcao))
    expect(linha.at_css("form")).to be_nil

    patch material_path(construcao.materia_prima), params: { materia_prima: { preco_metro: "1" } }
    expect(flash[:alert]).to include("o preço de um dublado é o preço final da construção dele")
    expect(construcao.materia_prima.reload.preco_metro).to eq(46)
  end

  # A dublado shares its superfície's group, color and width: an entry of
  # that fabric is never counted on the dublado.
  it "never registers a stock entry on a dublado" do
    construcao = montar_construcao([ oxford, "trama" ], [ lona, filme_35 ]).tap(&:save!)

    post movimentos_path, params: { movimento_estoque: { da_empresa: "true", tipo: "entrada", quantidade: "10", grupo_material_uuid: oxford.grupo_material.uuid,
                                                        cor_material_uuid: oxford.cor_material.uuid, largura: "1.40 m", gramatura: "" } }

    expect(MovimentoEstoque.last.materia_prima).to eq(oxford)
    expect(construcao.materia_prima.movimento_estoques).to be_empty
  end

  it "keeps the service per ligação on Parâmetros" do
    patch parametros_path, params: { empresa: { preco_servico_dublagem: "4,50" } }

    expect(Empresa.atual.preco_servico_dublagem).to eq(4.5)
  end
end
