require "rails_helper"

# Etapa 2.8 (1/5, decided 10/10/2026): the same screens for everyone, and a
# cliente final sees only its client's records. Two clients' data, the other
# client's marked "VAZOU" in every name; signed in as client A with every level
# and action of the grid, every GET route — by the other client's uuids and
# with the other's uuids in the query — must never show the mark. A new route
# is in this sweep without anyone adding it.
RSpec.describe "Visibilidade: no client sees another's records", type: :request, sem_login: true do
  MARCA = "VAZOU".freeze
  # Routes with no client records, or that need no sweep (sign-in, setup, Turbo native).
  FORA = %r{\A/(up|configuracao|session|senha|recede_historical_location|refresh_historical_location|resume_historical_location|rails|cable)}

  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:dados) { { a: dados_do_cliente("ALFA"), b: dados_do_cliente(MARCA) } }

  def dados_do_cliente(nome)
    client = create(:client, name: "Cliente #{nome}")
    molde = create(:molde, client: client, sufixo: "Molde #{nome}", partes: [ lateral ])
    corte = create(:arquivo, :corte, organized: true, filename: "corte-#{nome}", peca: lateral, modelo: molde.modelo).tap { |c| c.moldes << molde }
    tamanho = create(:tamanho, arquivo: corte, nome: "29-30", numeros: %w[29 30])
    arte = create(:arquivo, filename: "arte-#{nome}", client: client, molde: molde, peca: lateral, tamanho: tamanho)
    pedido = create(:pedido, client: client)
    create(:item_pedido, pedido: pedido, arquivo: arte).grades.create!(tamanho_nome: "30", quantidade: 1)
    # Materials are the empresa's common list: the same one for both clients.
    material = MateriaPrima.find_or_create_by!(grupo_material: GrupoMaterial.find_or_create_by!(nome: "Oxford"), cor_material: CorMaterial.find_or_create_by!(nome: "Azul"), largura: "1.40", gramatura: "80g")
    MovimentoEstoque.create!(client: client, materia_prima: material, tipo: "entrada", quantidade: 5)
    { client: client, molde: molde, corte: corte, tamanho: tamanho, arte: arte, pedido: pedido, peca: lateral }
  end

  def entrar_como_cliente(client)
    funcao = create(:funcao, niveis: Autorizacao::AREAS.index_with { |a| Autorizacao.nivel_maximo(a) }, acoes: Autorizacao::ACOES)
    user = create(:user)
    create(:vinculo, user: user, funcao: funcao, client: client)
    entrar_como(user)
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

  def vazamentos(b)
    consulta = { q: MARCA, molde_uuid: b[:molde].uuid, client_uuid: b[:client].uuid, peca_uuid: b[:peca].uuid }
    rotas_get.product([ b[:arte], b[:corte] ]).filter_map do |caminho, arquivo|
      url = preencher(caminho, b, arquivo)
      get url, params: consulta
      "#{url} (#{response.status})" if response.body.include?(MARCA)
    end.uniq
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
  end

  it "answers 404 to the other client's uuid" do
    entrar_como_cliente(dados[:a][:client])
    get arquivo_path(dados[:b][:arte])
    expect(response).to have_http_status(:not_found)
  end
end
