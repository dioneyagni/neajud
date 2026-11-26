require "rails_helper"

# Primeiros passos 1/6 (decided 26/11/2026, canvas "Primeiros passos"): an
# empty list shows the part's empty screen from config/mapa.yml — its icon,
# a title, the reason, one action for who may take it — and, to the team,
# what comes before it, the first missing part becoming the main action. A
# filter that left nothing is the other kind of empty: text and a way back.
RSpec.describe "Telas vazias", type: :request do
  def html = Nokogiri::HTML(response.body)
  def vazio(id) = html.at_css("[data-estado-vazio='#{id}']")

  # The Construções' material is missing, so its main action is the material's.
  it "shows each list's empty screen, with its icon in the block's color and its action" do
    { clients_path => [ "cliente", "Nenhum cliente ainda", "+ Novo cliente" ], pecas_path => [ "peca", "Nenhuma peça ainda", "+ Nova peça" ],
      materiais_path => [ "material", "Nenhum material ainda", "+ Lançar a primeira entrada" ], construcoes_path => [ "construcao", "Nenhuma construção ainda", "+ Lançar a primeira entrada" ],
      parametros_maquinas_path => [ "maquinas", "Nenhuma máquina ainda", "+ Nova máquina" ], parametros_turnos_path => [ "turnos", "Nenhum turno ainda", "Adicionar o primeiro turno" ] }
      .each do |pagina, (id, titulo, acao)|
        get pagina
        bloco = vazio(id)
        expect([ bloco&.at_css("h3")&.text, bloco&.at_css("[data-estado-vazio-acao]")&.text&.strip ].compact).to eq([ titulo, acao ].compact), "#{pagina}: #{bloco&.text&.squish.inspect}"
        expect(bloco.at_css(".estado-vazio-icone svg")["stroke"]).to eq("currentColor")
      end
  end

  it "says what the first pedido needs, the first missing part as the main action" do
    create(:client)
    get pedidos_path
    linhas = vazio("pedido").css("[data-falta]").map { |li| [ li["data-falta"], li["data-ok"], li.at_css("small").text ] }
    expect(linhas).to eq([ [ "clientes", "true", "· 1 cadastrados" ], [ "artes", "false", "· nenhuma ainda" ],
                           [ "moldes", "false", "· nenhum ainda" ], [ "materiais", "false", "· nenhum ainda" ] ])
    principal = vazio("pedido").at_css("a.btn-primary[data-estado-vazio-acao]")
    expect([ principal.text, principal["href"] ]).to eq([ "Enviar arquivos", "#{arquivos_path}#upload" ])
  end

  it "takes the part's own action once nothing is missing before it" do
    get clients_path
    expect(vazio("cliente").at_css("button[data-action='click->dialog#open']").text).to eq("+ Novo cliente")
    expect(vazio("cliente").at_css(".estado-vazio-depois").text.squish).to eq("Depois dele: Moldes · Artes · Pedidos")
  end

  it "tells a filter that left nothing apart from the first use" do
    create(:pedido, status: "rascunho")
    get pedidos_path(status: "entregue")
    expect([ vazio("pedido"), html.at_css("[data-estado-sem-resultado]").text ]).to eq([ nil, "Nenhum pedido com esse filtro · Limpar filtros" ])
    get arquivos_path(tipo: "dtf")
    expect([ vazio("arte"), html.at_css("[data-estado-sem-resultado]")&.text ]).to eq([ nil, "Nenhum arquivo deste tipo de trabalho · Limpar filtros" ])
  end

  it "shows the empty Painel what it needs, and the paradas row its link" do
    get painel_path
    expect(vazio("painel").css("[data-falta]").map { |li| li["data-falta"] }).to eq(%w[turnos ritmos pedidos_confirmados])
    expect(vazio("painel").at_css("a.btn-primary")["href"]).to eq("#{parametros_turnos_path}#turnos")
    get parametros_turnos_path
    expect(vazio("paradas").text.squish).to eq("Nenhuma parada. A previsão conta com todos os turnos. Nova parada")
  end

  # Who can't create doesn't get the button: the page itself refuses it.
  it "hides the action from who may not take it" do
    entrar_com_funcao(niveis: { "clientes" => 1 })
    get clients_path
    expect([ vazio("cliente").at_css("h3").text, vazio("cliente").at_css("[data-estado-vazio-acao]") ]).to eq([ "Nenhum cliente ainda", nil ])
  end

  # A cliente final sees only his own: the factory's "what comes before"
  # (clients, materials, turnos) is not his to settle.
  it "shows a cliente final no list of what comes before" do
    client = create(:client)
    funcao = create(:funcao, :para_cliente, niveis: (Autorizacao::AREAS - Autorizacao::AREAS_DA_EQUIPE).index_with(1))
    entrar_como(create(:vinculo, user: create(:user), funcao: funcao, client: client).user)
    get pedidos_path
    expect([ vazio("pedido").at_css("h3").text, vazio("pedido").css("[data-falta]").size ]).to eq([ "Nenhum pedido ainda", 0 ])
    get painel_path
    expect(vazio("painel")).to be_nil
  end
end
