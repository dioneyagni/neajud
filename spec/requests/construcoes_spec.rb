require "rails_helper"
require_relative "../support/construcoes"

# Dublagem 3/5 (decided 30/10-02/11/2026): the construções' list and form;
# since 5b1a the form sends the chave's cards (MontagemDaChave).
RSpec.describe "Construções", type: :request do
  let!(:oxford) { material_de_dublagem("Oxford", cor: "Preto", preco: 20) }
  let!(:lona) { material_de_dublagem("Lona", preco: 10) }
  let!(:filme_35) { material_de_dublagem("Filme", tipo: "filme", micras: 35, preco: 3) }

  def html = Nokogiri::HTML(response.body)

  # A card: em cima and embaixo each a material (or "dublagem:<i>"), the ligante.
  def card(cima, baixo, ligante = nil, lado: "trama")
    { cima: { escolha: cima.respond_to?(:uuid) ? cima.uuid : cima.to_s, lado: lado, do_cliente: "0" },
      baixo: { escolha: baixo.respond_to?(:uuid) ? baixo.uuid : baixo.to_s, do_cliente: "0" }, ligante_uuid: ligante&.uuid }
  end

  def formulario(*cards, **campos)
    { construcao: { situacao: "", client_uuid: "", preco_final: "", dublagens: cards.each_with_index.to_h { |dados, indice| [ indice.to_s, dados ] } }.merge(campos) }
  end

  def opcoes(seletor) = html.css("#{seletor} option").map(&:text).reject { |texto| texto.start_with?("—") }

  it "opens the new form with the superfícies and the price card" do
    get new_construcao_path

    expect(response).to have_http_status(:ok)
    expect(opcoes("#dublagem-0-cima")).to eq([ oxford.nome_completo ])
    expect(html.css("[data-dublagem]").map { |dublagem| dublagem["data-dublagem"] }).to eq([ "DUB-A" ])
    expect(html.css('input[name="construcao[situacao]"]').map { |radio| radio["value"] }).to eq([ "", "vai_frequencia", "tecido_molha" ])
    expect(html.at_css("[data-sugerido]").text).to eq("$0.00")
  end

  # Each change asks montar for the form again, nothing saved. Every base
  # is listed (5b1a): a pair the network doesn't have shows in red.
  it "rebuilds the form with the bases, the ligantes the network allows and the price" do
    helanca = material_de_dublagem("Helanca")
    Empresa.atual.update!(preco_servico_dublagem: 4)

    expect { post montar_construcoes_path, params: formulario(card(oxford, lona, filme_35)), as: :turbo_stream }.not_to change(Construcao, :count)

    expect(response.media_type).to eq("text/vnd.turbo-stream.html")
    expect(opcoes("#dublagem-0-baixo")).to contain_exactly(oxford.nome_completo, lona.nome_completo, helanca.nome_completo)
    expect(opcoes(".construcao-ligante")).to eq([ filme_35.nome_completo ])
    expect(html.at_css("[data-ligacao]").text.squish).to include("a confirmar")
    expect(html.at_css("[data-momento]").text).to eq("antes da Calandra")
    expect(html.at_css("[data-texto]").text).to eq("a estampa vai aqui · pela rede: Filme 35 µm ou mais, antes da estampa")
    expect(html.at_css("[data-sugerido]").text).to eq("$37.00")
  end

  # Q6a: "+ Juntar" adds an empty card; a letra chosen on a side goes into it,
  # and × lets it go again (the card, then empty, goes away).
  it "adds a card, joins a letra into it and lets it go on montar" do
    eva = material_de_dublagem("EVA")

    post montar_construcoes_path, params: formulario(card(oxford, lona, filme_35)).merge(acao: "nova"), as: :turbo_stream
    expect(html.css("[data-dublagem]").map { |dublagem| dublagem["data-dublagem"] }).to eq(%w[DUB-A DUB-B])
    expect(html.css("#dublagem-1-cima optgroup[label='Letras soltas'] option").map(&:text)).to eq([ "DUB-A · Oxford Preto / Lona Branco" ])

    juntando = formulario(card(oxford, lona, filme_35), card("dublagem:0", eva))
    post montar_construcoes_path, params: juntando, as: :turbo_stream
    expect(html.at_css('[data-dublagem="DUB-B"]').text.squish).to include("DUB-A / EVA Branco", "depois do DUB-A")
    expect(html.at_css("[data-problemas]").text).to include("DUB-B: Lona e EVA não dublam — a rede não tem essa ligação")
    expect(html.at_css("[data-falta-rede]").text.squish).to start_with("Lona + EVA não estão na rede.")

    post montar_construcoes_path, params: juntando.merge(acao: "tirar-1-cima"), as: :turbo_stream
    expect(html.css("[data-dublagem]").map { |dublagem| dublagem.at_css(".construcao-dublagem-nome").text }).to eq([ "Oxford Preto / Lona Branco", "material a escolher / EVA Branco" ])
    post montar_construcoes_path, params: formulario(card(oxford, lona, filme_35), card("dublagem:0", "")).merge(acao: "tirar-1-cima"), as: :turbo_stream
    expect(html.css("[data-dublagem]").map { |dublagem| dublagem["data-dublagem"] }).to eq([ "DUB-A" ])
  end

  it "saves a construção and its dublado, each base with its dublagem" do
    espuma = material_de_dublagem("Espuma", densidade: "TC4")
    helanca = material_de_dublagem("Helanca")
    post construcoes_path, params: formulario(card(espuma, helanca), card(oxford, "dublagem:0"), preco_final: "46,50")

    construcao = Construcao.last
    expect(response).to redirect_to(edit_construcao_path(construcao))
    expect(construcao.materia_prima).to have_attributes(tipo: "dublado", preco_metro: 46.5)
    expect(construcao.camadas.map { |camada| [ camada.posicao, camada.materia_prima, camada.ligante, camada.ordem_da_dublagem ] })
      .to eq([ [ 1, oxford, nil, nil ], [ 2, espuma, nil, 2 ], [ 3, helanca, nil, 1 ] ])
  end

  it "refuses a chave not closed, naming the pieces apart" do
    espuma = material_de_dublagem("Espuma", densidade: "TC4")
    helanca = material_de_dublagem("Helanca")

    post construcoes_path, params: formulario(card(oxford, lona, filme_35), card(espuma, helanca))

    expect(response).to have_http_status(:unprocessable_content)
    expect(flash[:alert]).to include("a chave não fechou: falta juntar DUB-A e DUB-B")
  end

  it "answers what is wrong, keeping the form" do
    helanca = material_de_dublagem("Helanca")

    post construcoes_path, params: formulario(card(oxford, helanca))

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("DUB-A: Oxford e Helanca não dublam — a rede não tem essa ligação")
    expect(html.at_css("#dublagem-0-baixo option[selected]").text).to eq(helanca.nome_completo)
    # Never the uuid of the construção that wasn't saved: montar would answer 404.
    expect(html.at_css("form.construcao-form")["data-construcao-uuid-value"]).to eq("")
  end

  # Decision 5: in use, only the final price changes.
  it "changes only the final price of a construção in use" do
    construcao = montar_construcao([ oxford, "trama" ], [ lona, filme_35 ]).tap(&:save!)
    MovimentoEstoque.create!(materia_prima: construcao.materia_prima, tipo: "entrada", quantidade: 5, da_empresa: true)

    get edit_construcao_path(construcao)
    expect(html.at_css("[data-em-uso]")).to be_present
    expect(html.at_css("#dublagem-0-cima")["disabled"]).to be_present
    expect(html.at_css("[data-juntar]")).to be_nil

    patch construcao_path(construcao), params: formulario(card(lona, oxford), preco_final: "50")
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

  it "keeps the service per ligação and the most layers on Parâmetros" do
    patch parametros_path, params: { empresa: { preco_servico_dublagem: "4,50", maximo_de_camadas: "6" } }

    expect(Empresa.atual).to have_attributes(preco_servico_dublagem: 4.5, maximo_de_camadas: 6)
  end

  # Q3c: lowering it below an active construção is refused, naming it.
  it "refuses on Parâmetros a most layers below an active construção" do
    construcao = montar_construcao([ oxford, "trama" ], [ oxford, filme_35 ], [ lona, filme_35 ]).tap(&:save!)

    patch parametros_path, params: { empresa: { maximo_de_camadas: "2" } }

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include(ERB::Util.html_escape(construcao.nome))
    expect(Empresa.atual.maximo_de_camadas).to eq(8)
  end
end
