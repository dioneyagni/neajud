require "rails_helper"

# Etapa 2.8 (4b, decided 12/10/2026): a cliente final writes only inside his
# client. Signed in as client A with the most a client's grid may give, every
# POST / PATCH / PUT / DELETE route is sent twice — his own records in the
# path with client B's uuids in the params, and B's records in the path —
# and afterwards nothing of B changed and nothing of A points at B. A new
# write route is in this sweep without anyone adding it.
RSpec.describe "Visibilidade: a client writes only inside his client", type: :request, sem_login: true do
  # Sign-in, the setup, the password and Turbo's own routes write no client records.
  FORA_DA_ESCRITA = %r{\A/(configuracao|session|senha|recede_historical_location|refresh_historical_location|resume_historical_location|rails|cable)}

  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:dados) { { a: dados_do_cliente("ALFA"), b: dados_do_cliente("BETA") } }
  let(:upload) { Rack::Test::UploadedFile.new(Rails.root.join("e2e/test-image.tif"), "image/tiff") }

  # Processing an upload is beside the point here: queue it, don't run it.
  around do |exemplo|
    adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    exemplo.run
  ensure
    ActiveJob::Base.queue_adapter = adapter
  end

  def dados_do_cliente(nome)
    client = create(:client, name: "Cliente #{nome}")
    molde = create(:molde, client: client, sufixo: "Molde #{nome}", partes: [ lateral ], preco: 10)
    corte = create(:arquivo, :corte, organized: true, filename: "corte-#{nome}", peca: lateral, modelo: molde.modelo).tap { |c| c.moldes << molde }
    tamanho = create(:tamanho, arquivo: corte, nome: "29-30", numeros: %w[29 30])
    arte = create(:arquivo, filename: "arte-#{nome}", client: client, molde: molde, peca: lateral, tamanho: tamanho)
    arte.update!(approved_version: create(:arquivo_version, arquivo: arte, version_number: 1, status: :processed))
    SolicitacaoAprovacao.create!(arquivo: arte, arquivo_version: arte.approved_version, user: create(:user))
    pedido = create(:pedido, client: client)
    create(:item_pedido, pedido: pedido, arquivo: arte).grades.create!(tamanho_nome: "30", quantidade: 1)
    referencia = Referencia.create!(molde: molde, nome: "Ref #{nome}")
    # Etapa 2.5a: a work in the coleção geral — every client reads it, none but its own changes it.
    colecao = create(:arquivo, filename: "colecao-#{nome}", client: client, arte: Arte.new(tipo: "dtf", no_catalogo: true))
    colecao.update!(approved_version: create(:arquivo_version, arquivo: colecao, version_number: 1, status: :processed))
    # Etapa 2.5b: a cor lisa in the coleção geral (its material is a write).
    colecao.arte.update_columns(tipo: "cor_lisa", familia: "Laranja", numero: nome == "ALFA" ? 1 : 2)
    { client: client, molde: molde, corte: corte, tamanho: tamanho, arte: arte, pedido: pedido, referencia: referencia, colecao: colecao }
  end

  def entrar_como_cliente(client)
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE, acoes: Autorizacao::ACOES - Autorizacao::ACOES_DA_EQUIPE)
    entrar_como(create(:vinculo, user: create(:user), funcao: funcao, client: client).user)
  end

  def rotas_de_escrita
    Rails.application.routes.routes.filter_map do |rota|
      verbo = rota.verb.to_s[/POST|PATCH|PUT|DELETE/]
      caminho = rota.path.spec.to_s.sub("(.:format)", "")
      [ verbo.downcase.to_sym, caminho ] if verbo && caminho.start_with?("/") && !caminho.match?(FORA_DA_ESCRITA)
    end.uniq
  end

  # Each path segment from one client's records; the first path component
  # says which record :id is.
  def preencher(caminho, d)
    raiz = caminho.split("/")[1]
    id = { "arquivos" => d[:arte], "clients" => d[:client], "moldes" => d[:molde], "tamanhos" => d[:tamanho], "pedidos" => d[:pedido],
           "solicitacoes_aprovacao" => d[:arte].arte.solicitacoes_aprovacao.first }.fetch(raiz, nil)&.uuid || SecureRandom.uuid
    valores = { "id" => id, "uuid" => id, "arquivo_id" => d[:arte].uuid, "molde_id" => d[:molde].uuid, "pedido_id" => d[:pedido].uuid, "etapa" => "estamparia" }
    caminho.gsub(/:(\w+)/) { valores.fetch(Regexp.last_match(1), SecureRandom.uuid) }
  end

  # The other client's uuids in every param a write may read.
  def params_de(b)
    uuids = { client_uuid: b[:client].uuid, molde_uuid: b[:molde].uuid, tamanho_uuid: b[:tamanho].uuid, referencia_uuid: b[:referencia].uuid,
              arte_uuid: b[:arte].arte.uuid, version_uuid: b[:arte].approved_version.uuid, original_uuid: b[:arte].uuid, pedido_uuid: b[:pedido].uuid }
    uuids.merge(origem_uuids: [ b[:arte].uuid ], arquivo_ids: [ b[:arte].uuid ], original_file: upload, recado: "x", nome: "Trocado",
                arquivo: uuids.slice(:client_uuid, :molde_uuid, :arte_uuid).merge(original_file: upload),
                molde: uuids.slice(:client_uuid).merge(sufixo: "Novo"), movimento_estoque: uuids.slice(:client_uuid))
  end

  # Everything of B a write could touch, and what of A could point at B.
  def foto(a, b)
    arte_b = b[:arte].arte
    {
      registros_de_b: [ b[:client], b[:molde], b[:corte], b[:tamanho], b[:arte], b[:pedido], b[:referencia], b[:colecao], b[:colecao].arte ].map { |r| r.class.find(r.id).attributes.except("updated_at") },
      contagens_de_b: [ Arquivo.where(client: b[:client]).count, arte_b.arquivos.count, ArquivoVersion.where(arquivo: b[:arte]).count,
                        AprovacaoArte.where(arte: arte_b).count, AlteracaoArte.where(arte: arte_b).count, SolicitacaoAprovacao.where(arte: arte_b).count,
                        Molde.where(client: b[:client]).count, Referencia.where(molde: b[:molde]).count, MovimentoEstoque.where(client: b[:client]).count,
                        ItemPedido.where(pedido: b[:pedido]).count, b[:colecao].arte.arquivos.count, ArquivoVersion.where(arquivo: b[:colecao]).count, EventoPedido.where(pedido: b[:pedido]).count, ArquivoMolde.where(molde: b[:molde]).count ],
      a_aponta_para_b: Arquivo.where(client: a[:client]).where(molde: b[:molde]).or(Arquivo.where(client: a[:client], tamanho: b[:tamanho]))
                              .or(Arquivo.where(client: a[:client], arte: arte_b)).or(Arquivo.where(client: a[:client], referencia: b[:referencia])).count
    }
  end

  def alteracoes(a, b)
    rotas_de_escrita.flat_map do |verbo, caminho|
      # B's work in the coleção geral in the path too: he reads it, never writes it.
      [ a, b, b.merge(arte: b[:colecao]) ].filter_map do |no_caminho|
        antes = foto(a, b)
        url = preencher(caminho, no_caminho)
        public_send(verbo, url, params: params_de(b))
        "#{verbo.upcase} #{url} (#{response.status})" if foto(a, b) != antes
      end
    end
  end

  it "sends every write route with the other client's uuids and changes nothing of his" do
    a = dados[:a]
    b = dados[:b]
    entrar_como_cliente(a[:client])
    expect(alteracoes(a, b)).to eq([])
  end

  # The sweep isn't passing on refusals alone: his own upload goes through, as his.
  it "still lets him upload an arte, which is his client's" do
    a = dados[:a]
    entrar_como_cliente(a[:client])
    post arquivos_path, params: { arquivo: { original_file: upload } }
    expect(Arquivo.order(:id).last).to have_attributes(client: a[:client], category: "artes")
  end
end
