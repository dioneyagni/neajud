require "rails_helper"

# Etapa 1.2 (2/3, parte 3): grouping at upload.
RSpec.describe "Upload grouping", type: :request do
  around do |example|
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = :inline
  end

  let!(:lateral) { create(:peca, nome: "Lateral") }

  def upload(nome) = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/02-no_spot.tif"), "image/tiff", original_filename: nome)

  it "answers the groups with each file's part, size and suggested piloto, and the existing artes" do
    create(:peca, nome: "Língua")
    existente = create(:arquivo, filename: "20-BLUEY-LINGUA")
    post agrupamento_arquivos_path, params: { arquivos: [
      { nome: "20-BLUEY-LATERAL.tif", bytes: 80_000_000 }, { nome: "20-bluey-LATERAL-23_24.tif", bytes: 5_000_000 },
      { nome: "20-bluey-LATERAL-25_26.tif", bytes: 5_000_000 }
    ] }, as: :json
    corpo = response.parsed_body
    expect(corpo["conferir"]).to be true
    grupo = corpo["grupos"].sole
    expect(grupo["titulo"]).to eq("20 · BLUEY")
    expect(grupo["arquivos"].map { |a| a.values_at("indice", "parte_uuid", "tamanho", "piloto") })
      .to eq([ [ 0, lateral.uuid, nil, true ], [ 1, lateral.uuid, "23-24", false ], [ 2, lateral.uuid, "25-26", false ] ])
    expect(grupo["existentes"].map { |e| e["arte_uuid"] }).to eq([ existente.arte.uuid ])
    expect(corpo["pecas"]).to include({ "uuid" => lateral.uuid, "nome" => "Lateral" })
  end

  it "creates an empty arte for a group" do
    expect { post artes_path, as: :json }.to change(Arte, :count).by(1)
    expect(response.parsed_body["uuid"]).to eq(Arte.last.uuid)
  end

  describe "the upload with the group's choices" do
    it "puts the file in the arte, with its part, size and role" do
      arte = Arte.create!
      post arquivos_path, params: { arquivo: { original_file: upload("20-x.tif"), arte_uuid: arte.uuid, peca_uuid: lateral.uuid, tamanho_rotulo: "30", papel: "piloto" } }
      novo = Arquivo.order(:id).last
      expect([ novo.arte, novo.peca, novo.tamanho_rotulo, novo.papel ]).to eq([ arte, lateral, "30", "piloto" ])
    end

    it "into an existing arte, the file takes its molde, client, referência and nome" do
      molde = create(:molde)
      existente = create(:arquivo, molde: molde, nome: "Bluey")
      post arquivos_path, params: { arquivo: { original_file: upload("20-bluey-31_32.tif"), arte_uuid: existente.arte.uuid } }
      novo = Arquivo.order(:id).last
      expect([ novo.arte_id, novo.molde_id, novo.client_id, novo.nome ]).to eq([ existente.arte_id, molde.id, molde.client_id, "Bluey" ])
    end

    it "keeps a DXF sent with an arte a corte of its own" do
      dxf = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/29-30.dxf"), "image/vnd.dxf")
      post arquivos_path, params: { arquivo: { original_file: dxf, arte_uuid: Arte.create!.uuid } }
      expect(Arquivo.order(:id).last.attributes.values_at("category", "arte_id")).to eq([ "corte", nil ])
    end
  end
end
