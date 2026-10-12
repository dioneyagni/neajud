require "rails_helper"

# Etapa 2.8 (1/5, decided 10/10/2026): the same screens for everyone, and a
# cliente final sees only its client's records. Two clients' data, the other
# client's marked "VAZOU" in every name; signed in as client A with every level
# and action of the grid, every GET route — by the other client's uuids and
# with the other's uuids in the query — must never show the mark. A new route
# is in this sweep without anyone adding it.
RSpec.describe "Visibilidade: no client sees another's records", type: :request, sem_login: true do
  MARCA = "VAZOU".freeze
  # The molde's price per pair, as the pages write it ("R$ 987,65").
  PRECO = 987.65
  # Routes with no client records, or that need no sweep (sign-in, setup, Turbo native).
  FORA = %r{\A/(up|configuracao|session|senha|recede_historical_location|refresh_historical_location|resume_historical_location|rails|cable)}

  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:dados) { { a: dados_do_cliente("ALFA"), b: dados_do_cliente(MARCA) } }

  def dados_do_cliente(nome)
    client = create(:client, name: "Cliente #{nome}")
    molde = create(:molde, client: client, sufixo: "Molde #{nome}", partes: [ lateral ], preco: PRECO)
    corte = create(:arquivo, :corte, organized: true, filename: "corte-#{nome}", peca: lateral, modelo: molde.modelo).tap { |c| c.moldes << molde }
    tamanho = create(:tamanho, arquivo: corte, nome: "29-30", numeros: %w[29 30])
    arte = create(:arquivo, filename: "arte-#{nome}", client: client, molde: molde, peca: lateral, tamanho: tamanho)
    pedido = create(:pedido, client: client)
    create(:item_pedido, pedido: pedido, arquivo: arte).grades.create!(tamanho_nome: "30", quantidade: 1)
    # Materials are the empresa's common list: the same one for both clients.
    material = MateriaPrima.find_or_create_by!(grupo_material: GrupoMaterial.find_or_create_by!(nome: "Oxford"), cor_material: CorMaterial.find_or_create_by!(nome: "Azul"), largura: "1.40", gramatura: "80g")
    movimento = MovimentoEstoque.create!(client: client, materia_prima: material, tipo: "entrada", quantidade: 5)
    faixa = molde.faixas_de_preco.first
    # Etapa 2.5a: an etiqueta of his own, and one in the coleção geral — every
    # client reads it, never whose it is.
    dtf = create(:arquivo, filename: "dtf-#{nome}", client: client, arte: Arte.novo_do_tipo("dtf"))
    colecao = create(:arquivo, filename: "colecao-#{nome.downcase.reverse}", client: client, arte: Arte.new(tipo: "dtf", no_catalogo: true))
    # Etapa 2.5b: his own cor lisa, the same tone for both clients — "Cores"
    # and the near colors of A's page must never show B's (family "VAZOU").
    cor = create(:arquivo, filename: "cor-#{nome}", client: client, arte: Arte.new(tipo: "cor_lisa"))
    cor.arte.update_columns(familia: nome, numero: 1)
    cor.update!(approved_version: create(:arquivo_version, arquivo: cor, version_number: 1, status: :processed, lab_l: 54.3, lab_a: 64.7, lab_b: 55.3, cor_hex: "#EF4123"))
    { cor: cor, client: client, molde: molde, corte: corte, tamanho: tamanho, arte: arte, pedido: pedido, peca: lateral, movimento: movimento, faixa: faixa, dtf: dtf, colecao: colecao }
  end

  # Every level and action, the team's too — more than a função para clientes
  # may have (2/5) — so no route is skipped for lack of permission: what is
  # swept is whose records show, not what the grid allows.
  def entrar_como_cliente(client)
    funcao = create(:funcao, :para_cliente)
    funcao.update_columns(niveis: Autorizacao::AREAS.index_with { |a| Autorizacao.nivel_maximo(a) }, acoes: Autorizacao::ACOES)
    user = create(:user)
    create(:vinculo, user: user, funcao: funcao, client: client)
    entrar_como(user)
    @cliente_final = user
  end

  def rotas_get
    Rails.application.routes.routes.filter_map do |rota|
      caminho = rota.path.spec.to_s.sub("(.:format)", "")
      caminho if rota.verb.to_s.include?("GET") && !caminho.match?(FORA) && caminho.start_with?("/")
    end.uniq
  end

  # The other client's record for each path segment; nil = no such record.
  def preencher(caminho, b, arquivo)
    valores = { "id" => id_do(caminho, b, arquivo), "uuid" => (caminho.start_with?("/pedidos") ? b[:pedido].uuid : SecureRandom.uuid),
                "arquivo_id" => arquivo.uuid, "molde_id" => b[:molde].uuid, "pedido_id" => b[:pedido].uuid, "etapa" => "estamparia", "tipo" => "arquivos" }
    caminho.gsub(/:(\w+)/) { valores.fetch(Regexp.last_match(1)) }
  end

  def id_do(caminho, b, arquivo)
    { "arquivos" => arquivo.uuid, "clients" => b[:client].uuid, "moldes" => b[:molde].uuid, "tamanhos" => b[:tamanho].uuid,
      "pecas" => b[:peca].uuid, "modelos" => b[:molde].modelo.uuid }.fetch(caminho.split("/")[1], SecureRandom.uuid)
  end

  def vazamentos(b, marcas: { MARCA => MARCA })
    consulta = { q: MARCA, molde_uuid: b[:molde].uuid, client_uuid: b[:client].uuid, peca_uuid: b[:peca].uuid }
    rotas_get.product([ b[:arte], b[:corte], b[:dtf], b[:colecao] ]).filter_map do |caminho, arquivo|
      url = preencher(caminho, b, arquivo)
      get url, params: consulta
      vistas = marcas.select { |_, marca| response.body.include?(marca) && !eco?(marca, consulta) }.keys + canais_proibidos
      "#{url} (#{response.status}): #{vistas.join(", ")}" if vistas.any?
    end.uniq
  end

  # Etapa 2.8 (3b): the live streams a page subscribes are signed, so no mark
  # shows in them — each must be one AoVivoChannel lets him listen to.
  def canais_da_pagina
    Nokogiri::HTML(response.body).css("turbo-cable-stream-source").map { |tag| [ tag["channel"], CanaisAoVivo.ler(tag["signed-stream-name"]) ] }
  end

  def canais_proibidos
    canais_da_pagina.filter_map do |canal, nome|
      "stream #{canal} #{nome.inspect}" unless canal == "AoVivoChannel" && nome && CanaisAoVivo.permitido?(@cliente_final, nome)
    end
  end

  # A uuid the request itself sent, written back by an error page or a
  # hidden field (pecas/new keeps molde_uuid), is no record shown. The
  # VAZOU mark is never sent as a uuid, so the other-client sweep is untouched.
  # A format the action doesn't answer (406, a JSON-only route asked for a
  # page) renders Rails' debug page, which reprints the request — the query's
  # q=VAZOU included (seen once the coleção geral opened a B file, 2.5a).
  def eco?(marca, consulta)
    return true if response.status == 406
    return false if marca == MARCA

    response.status >= 400 || consulta.except(:q).values.include?(marca)
  end

  # What each closed kind hides (Etapa 2.8, 3a): its records' uuids — every
  # link or form to them carries one — and the price per pair.
  def marcas_dos_tipos_fechados(a)
    a.slice(:pedido, :molde, :corte, :tamanho, :movimento, :faixa).transform_values(&:uuid).merge(preco: "987,65")
  end

  it "sweeps every GET route as client A and never shows client B's records" do
    b = dados[:b]
    entrar_como_cliente(dados[:a][:client])
    expect(vazamentos(b)).to eq([])
  end

  it "still shows client A its own records (the sweep isn't passing on empty pages)" do
    a = dados[:a]
    entrar_como_cliente(a[:client])
    { "/arquivos" => "arte-ALFA", "/moldes" => "Molde ALFA", "/clients" => "Cliente ALFA", "/pedidos/#{a[:pedido].uuid}" => "Cliente ALFA" }.each do |url, texto|
      get url
      expect(response.body).to include(texto), "#{url} should show #{texto}"
    end
    get arquivos_path
    expect(canais_da_pagina).to eq([ [ "AoVivoChannel", "cartoes:#{a[:client].uuid}" ] ])
  end

  # Etapa 2.8 (3a): a kind his grid closes hides his own records too.
  it "sweeps every GET route as a client whose grid closes every kind and never shows his records of them" do
    a = dados[:a]
    a[:client].update!(visibilidade: TiposParaCliente::TIPOS.index_with(false))
    entrar_como_cliente(a[:client])
    expect(vazamentos(a, marcas: marcas_dos_tipos_fechados(a))).to eq([])
  end

  it "doesn't let him download an original while that kind is closed" do
    a = dados[:a]
    a[:client].update!(visibilidade: { "original" => false, "cortes" => true })
    entrar_como_cliente(a[:client])
    [ download_arquivo_path(a[:arte]), download_tamanho_path(a[:tamanho]) ].each do |url|
      get url
      expect(response.status).to be >= 400, "#{url} answered #{response.status}"
    end
  end

  # Etapa 2.5a: the coleção geral is open to read, without its owner.
  it "shows client A the other's work in the coleção geral, and never his own etiqueta" do
    b = dados[:b]
    entrar_como_cliente(dados[:a][:client])
    get arquivos_path
    expect(response.body).to include(b[:colecao].filename)
    get arquivo_path(b[:colecao])
    expect(response).to have_http_status(:ok)
    get arquivo_path(b[:dtf])
    expect(response).to have_http_status(:not_found)
  end

  it "never shows client A the other's cor lisa among the near colors of his own" do
    a = dados[:a]
    dados[:b]
    entrar_como_cliente(a[:client])
    get arquivo_path(a[:cor])
    expect(response.body).to include("ALFA 1")
    expect(response.body).not_to include(MARCA)
  end

  it "answers 404 to the other client's uuid" do
    entrar_como_cliente(dados[:a][:client])
    get arquivo_path(dados[:b][:arte])
    expect(response).to have_http_status(:not_found)
  end
end
