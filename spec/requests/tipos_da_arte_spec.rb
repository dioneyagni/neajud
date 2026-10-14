require "rails_helper"

# Etapa 2.5a (decided 12/10/2026): the kind of work chosen in the upload,
# changed on the arte page, and "Entra no catálogo" — the team's.
RSpec.describe "The kind of work of an arte", type: :request do
  let(:upload) { Rack::Test::UploadedFile.new(Rails.root.join("e2e/test-image.tif"), "image/tiff") }
  let(:client) { create(:client) }

  around do |exemplo|
    adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    exemplo.run
  ensure
    ActiveJob::Base.queue_adapter = adapter
  end

  def entrar_como_cliente_final(cliente = client)
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user), client: cliente, funcao: funcao).user)
  end

  it "a file uploaded alone gets an arte of the upload's kind, numbered" do
    post arquivos_path, params: { arquivo: { original_file: upload, tipo: "dtf" } }, headers: { "Accept" => "application/json" }
    expect(Arte.find_by!(uuid: response.parsed_body["arte_uuid"])).to have_attributes(tipo: "dtf", codigo: "DTF-1")
  end

  it "a group's arte is made of its kind, and an unknown kind is refused" do
    post artes_path, params: { tipo: "corrida" }, as: :json
    expect(Arte.find_by!(uuid: response.parsed_body["uuid"]).codigo).to eq("CR-1")
    post artes_path, params: { tipo: "bordado" }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "changes the kind on the arte page and marks it Entra no catálogo" do
    arquivo = create(:arquivo, category: "artes", client: client)
    patch arquivo_tipo_da_arte_path(arquivo), params: { tipo: "dtf" }
    expect(flash[:notice]).to include("Etiqueta DTF (DTF-1)")
    patch catalogo_arquivo_tipo_da_arte_path(arquivo), params: { no_catalogo: "1" }
    expect(arquivo.arte.reload.no_catalogo).to be(true)
  end

  # Pedidos are calçado's and DTF's (Etapa 2.6b1) until the tecido's (2.7).
  it "keeps a corrida out of pedidos" do
    arquivo = create(:arquivo, category: "artes", client: client, arte: Arte.novo_do_tipo("corrida"))
    post adicionar_item_pedidos_path, params: { arquivo_uuid: arquivo.uuid, grade: { "_total" => 2 } }, as: :json
    expect(response.parsed_body["error"]).to include("only calçado and DTF artes go into a pedido")
    get arquivos_path
    expect(Nokogiri::HTML(response.body).css("##{CanaisAoVivo.id_do_cartao(arquivo)} .btn-add-to-order")).to be_empty
  end

  it "filters the gallery by kind" do
    create(:arquivo, category: "artes", filename: "tenis-x")
    create(:arquivo, category: "artes", filename: "etiqueta-x", arte: Arte.novo_do_tipo("dtf"))
    get arquivos_path(tipo: "dtf")
    expect(response.body).to include("etiqueta-x").and include("DTF-1")
    expect(response.body).not_to include("tenis-x")
  end

  it "a cliente final reads another client's work in the catálogo, but never changes it nor sees whose it is" do
    outro = create(:client, name: "Cliente Dono")
    colecao = create(:arquivo, category: "artes", client: outro, filename: "colecao-y", arte: Arte.new(tipo: "dtf", no_catalogo: true))
    entrar_como_cliente_final
    get arquivo_path(colecao)
    expect(response).to have_http_status(:ok)
    expect(response.body).not_to include("Cliente Dono", "Change kind", "Add a file")
    patch arquivo_tipo_da_arte_path(colecao), params: { tipo: "corrida" }
    expect(response).to have_http_status(:not_found)
    expect(colecao.arte.reload.tipo).to eq("dtf")
  end

  it "Entra no catálogo is the team's, even for the client's own etiqueta" do
    proprio = create(:arquivo, category: "artes", client: client, arte: Arte.novo_do_tipo("dtf"))
    entrar_como_cliente_final
    patch catalogo_arquivo_tipo_da_arte_path(proprio), params: { no_catalogo: "1" }
    expect(response).to have_http_status(:forbidden)
    expect(proprio.arte.reload.no_catalogo).to be(false)
  end

  # Etapa 2.6a (decided 13/10/2026): a DTF's spacing on the film, the team's.
  it "the team sets a DTF's own spacing, blank going back to the dono's default" do
    arquivo = create(:arquivo, category: "artes", client: client, arte: Arte.novo_do_tipo("dtf"))
    get arquivo_path(arquivo)
    expect(Nokogiri::HTML(response.body).at_css("#espacamento-dtf-mm")["placeholder"]).to eq("1,5")
    patch espacamento_arquivo_tipo_da_arte_path(arquivo), params: { espacamento_mm: "2,5" }
    expect([ arquivo.arte.reload.espacamento_mm, flash[:notice] ]).to eq([ 2.5, "Spacing of #{arquivo.arte.titulo}: 2,5 mm." ])
    patch espacamento_arquivo_tipo_da_arte_path(arquivo), params: { espacamento_mm: "" }
    expect(arquivo.arte.reload.espacamento_efetivo_mm).to eq(1.5)
    patch espacamento_arquivo_tipo_da_arte_path(arquivo), params: { espacamento_mm: "-1" }
    expect(flash[:alert]).to include("Espacamento mm must be greater than or equal to 0")
  end

  it "the cliente final neither sees nor sets his own DTF's spacing" do
    proprio = create(:arquivo, category: "artes", client: client, arte: Arte.novo_do_tipo("dtf"))
    entrar_como_cliente_final
    get arquivo_path(proprio)
    # A production setting of the factory, not the client's (decided 13/10/2026).
    expect(response.body).not_to include("espacamento-dtf-section")
    patch espacamento_arquivo_tipo_da_arte_path(proprio), params: { espacamento_mm: "9" }
    expect(response).to have_http_status(:forbidden)
    expect(proprio.arte.reload.espacamento_mm).to be_nil
  end

  it "shows each DTF size's measure from its file, in cm" do
    arte = Arte.novo_do_tipo("dtf").tap(&:save!)
    arquivo = create(:arquivo, category: "artes", client: client, arte: arte, tamanho_rotulo: "P")
    versao = create(:arquivo_version, arquivo: arquivo, approved: true)
    ArquivoImageMetadata.create!(arquivo_version: versao, width_px: 191, height_px: 201, dpi: 300)
    arquivo.update!(approved_version: versao)
    get arquivo_path(arquivo)
    expect(Nokogiri::HTML(response.body).at_css("#arte-arquivos .arte-arquivo-medida").text).to eq("1,62 × 1,70 cm")
  end
end
