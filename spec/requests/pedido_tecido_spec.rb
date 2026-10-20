require "rails_helper"
require_relative "../support/tecidos"

# Etapa 2.7a (decided 16/10/2026): the tecido pedido — corridas and cores
# lisas, each item an arte on a fabric in linear meters (one decimal) on a
# width that follows the material's; whose fabric it is, once for the
# pedido; its client the pedido's (as the DTF's D4), never split.
RSpec.describe "The tecido pedido", type: :request do
  let(:client) { create(:client, name: "Malharia Sul") }
  let(:oxford) { criar_tecido(largura: "1.50") }
  let(:cor) { criar_obra_de_tecido("cor_lisa", client: client, no_catalogo: false, materia_prima: oxford) }
  let(:corrida) { criar_obra_de_tecido("corrida", client: client) }
  # Etapa 2.7b: no price, no confirming (spec/requests/precos_tecido_spec.rb covers them).
  before { Empresa.atual.update!(preco_impressao_metro_tecido: 15) }

  def adicionar(arte, **params)
    post adicionar_item_pedidos_path, params: { arquivo_uuid: arte.arquivos.first.uuid, **params }, as: :json
    response.parsed_body
  end

  def entrar_como_cliente_final(cliente)
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user), client: cliente, funcao: funcao).user)
  end

  it "a corrida and a cor lisa go into their client's tecido draft, in meters, without parts" do
    pedido = Pedido.find_by!(uuid: adicionar(cor, metros: "12,5")["pedido_uuid"])
    expect(adicionar(corrida, metros: "3", materia_prima_uuid: oxford.uuid)["pedido_uuid"]).to eq(pedido.uuid)
    # Whose fabric: blank, inherits the client's (Etapa 2.3d1), "cliente" by default.
    expect([ pedido.tipo, pedido.client, pedido.dono_tecido, DonoDoTecido.do_pedido(pedido).dono ]).to eq([ "tecido", client, nil, "cliente" ])
    # A blank material takes the cor lisa's.
    expect(pedido.itens_pedido.order(:id).map { |i| [ i.metros, i.materia_prima, i.item_pedido_pecas.size, i.grades.size ] }).to eq([ [ 12.5, oxford, 0, 0 ], [ 3, oxford, 0, 0 ] ])
  end

  it "refuses no meters, two decimals and a material that is no fabric" do
    expect(adicionar(cor)["error"]).to eq("Informe os metros (maior que 0).")
    expect(adicionar(cor, metros: "1,25")["error"]).to include("1.25 has more than one decimal; expected meters like 12,5")
    expect(adicionar(cor, metros: "1", materia_prima_uuid: criar_tecido(tipo: "papel", grupo: "Papel").uuid)["error"]).to include("Couldn't find MateriaPrima")
    expect(Pedido.count).to eq(0)
  end

  it "takes a catálogo cor lisa into any client's pedido, and refuses a tecido into a calçado pedido" do
    catalogo = criar_obra_de_tecido("cor_lisa", client: create(:client, name: "Outra"))
    pedido = create(:pedido, client: client, tipo: "tecido")
    adicionar(catalogo, metros: "2", pedido_uuid: pedido.uuid)
    expect([ pedido.reload.itens_pedido.size, pedido.bloqueios_confirmacao.map(&:tipo) ]).to eq([ 1, %i[sem_material] ])
    calcado = create(:pedido, client: client).tap { |p| create(:item_pedido, :com_quantidade, pedido: p) }
    expect(adicionar(cor, metros: "1", pedido_uuid: calcado.uuid)["error"]).to include("is a calcado pedido; #{cor.titulo} goes into a tecido one")
  end

  it "shows each item's fabric, meters and width, the owner's balance and a width past the paper" do
    Empresa.atual.update!(largura_papel_mm: 1600)
    largo = criar_tecido(largura: "1.80", grupo: "Tricoline")
    MovimentoEstoque.create!(materia_prima: largo, client: client, tipo: "entrada", quantidade: 30)
    pedido = Pedido.find_by!(uuid: adicionar(cor, metros: "12,5", materia_prima_uuid: largo.uuid)["pedido_uuid"])
    get resumo_pedido_path(pedido)
    html = Nokogiri::HTML(response.body)
    item = html.at_css(".pedido-item-tecido")
    expect(item.at_css(".pedido-tecido-material option[selected]").text).to eq("#{largo.nome_completo} · saldo 30 m")
    expect([ item.at_css(".pedido-tecido-metros")["value"], item.at_css(".pedido-tecido-largura-mm")["placeholder"] ]).to eq([ "12,5", "1800" ])
    expect(item.at_css(".pedido-tecido-aviso").text).to eq("Mais larga que o papel (1,6 m): confira se há papel para ela")
    expect(%w[itens metros dono-tecido].map { |c| html.at_css("[data-resumo='#{c}']").text }).to eq([ "1", "12,5 m", "Do cliente (padrão)" ])
    # Its stages since 2.7c (the paper, then the Calandra); a DTF's values never.
    expect(html.css(".pedido-ir-producao a").map(&:text)).to eq([ "Impressão →", "Calandra →" ])
    expect(html.css("#valores-dtf")).to be_empty
  end

  it "the team sets the fabric owner, an item's fabric, meters and width" do
    pedido = Pedido.find_by!(uuid: adicionar(corrida, metros: "1")["pedido_uuid"])
    item = pedido.itens_pedido.first
    patch materiais_pedido_path(pedido), params: { dono_tecido: "empresa" }
    patch tecido_item_pedido_path(pedido), params: { item_uuid: item.uuid, materia_prima_uuid: oxford.uuid, metros: "7,5", largura_mm: "1400" }
    expect([ pedido.reload.dono_tecido, item.reload.materia_prima, item.metros, item.largura_efetiva_mm ]).to eq([ "empresa", oxford, 7.5, 1400 ])
    patch tecido_item_pedido_path(pedido), params: { item_uuid: item.uuid, largura_mm: "" }
    expect(item.reload.largura_efetiva_mm).to eq(1500)
    patch materiais_pedido_path(pedido), params: { dono_tecido: "vizinho" }
    expect(flash[:alert]).to include("vizinho is not whose fabric; expected one of cliente, empresa or blank (inherits)")
  end

  # Decided 16/10/2026: the width is the team's — how far the RIP repeats the module.
  it "a cliente final changes his draft's fabric, meters and owner, never the width or the client" do
    pedido = Pedido.find_by!(uuid: adicionar(cor, metros: "1")["pedido_uuid"])
    item = pedido.itens_pedido.first
    entrar_como_cliente_final(client)
    patch tecido_item_pedido_path(pedido), params: { item_uuid: item.uuid, metros: "4" }
    patch materiais_pedido_path(pedido), params: { dono_tecido: "empresa" }
    patch tecido_item_pedido_path(pedido), params: { item_uuid: item.uuid, metros: "9", largura_mm: "900" }
    expect(flash[:alert]).to eq("The width is the team's to set")
    patch tecido_pedido_path(pedido), params: { client_uuid: create(:client).uuid }
    expect([ item.reload.metros, item.largura_mm, pedido.reload.dono_tecido, pedido.client ]).to eq([ 4, nil, "empresa", client ])
    get resumo_pedido_path(pedido)
    html = Nokogiri::HTML(response.body)
    expect([ html.css(".pedido-tecido-largura-mm").size, html.at_css(".pedido-tecido-largura").text ]).to eq([ 0, "1,5 m" ])
  end

  it "blocks confirming without client, an arte of another, no fabric, no meters or no width" do
    sem_largura = criar_tecido(largura: "larga", grupo: "Linho")
    outra = criar_obra_de_tecido("corrida", client: create(:client, name: "Outra"))
    pedido = create(:pedido, tipo: "tecido")
    [ [ outra, nil, 1 ], [ corrida, nil, 0 ], [ cor, sem_largura, 2 ] ].each { |arte, material, metros| create(:item_pedido, pedido: pedido, arquivo: arte.arquivos.first, materia_prima: material, metros: metros) }
    expect(pedido.bloqueios_confirmacao.map(&:tipo)).to eq(%i[pedido_sem_cliente arte_de_outro_cliente arte_de_outro_cliente arte_de_outro_cliente sem_material sem_material zerado sem_largura])
    pedido.update!(client: client)
    expect(pedido.bloqueios_confirmacao.map(&:descricao)).to include("Arte #{outra.titulo} é de Outra, não do cliente do pedido", "#{cor.titulo} sem largura: o material #{sem_largura.nome_completo} não diz a largura; informe-a no item")
  end

  it "confirms without splitting; the calçado's production pages lead to its own (Etapa 2.7c)" do
    catalogo = criar_obra_de_tecido("cor_lisa", client: create(:client, name: "Outra"), materia_prima: oxford)
    pedido = Pedido.find_by!(uuid: adicionar(cor, metros: "2")["pedido_uuid"])
    adicionar(catalogo, metros: "3", pedido_uuid: pedido.uuid)
    post confirmar_pedido_path(pedido)
    expect([ pedido.reload.status, pedido.client, Pedido.count ]).to eq([ "confirmado", client, 1 ])
    get impressao_pedido_path(pedido)
    expect(response).to redirect_to(producao_tecido_pedido_path(pedido, etapa: "impressao"))
  end

  it "finds corridas and cores lisas by number, name or color family, the catálogo's too" do
    cor.update_columns(familia: "Laranja", numero: 3)
    alheia = criar_obra_de_tecido("cor_lisa", client: create(:client, name: "Outra"), filename: "azul-x")
    alheia.update_columns(familia: "Azul", numero: 3)
    criar_etiqueta = Arte.novo_do_tipo("dtf").tap(&:save!)
    create(:arquivo, category: "artes", arte: criar_etiqueta, client: client, filename: "laranja-dtf")
    buscar = ->(q) { get artes_para_adicionar_pedidos_path(tipo: "tecido", q: q), as: :json; response.parsed_body["artes"].map { |a| a["titulo"] } }
    expect(buscar.("Laranja 3")).to eq([ cor.reload.titulo ])
    expect(buscar.("3")).to contain_exactly(cor.titulo, alheia.reload.titulo)
    expect(buscar.("CR-#{corrida.numero}")).to eq([ corrida.titulo ])
  end
end
