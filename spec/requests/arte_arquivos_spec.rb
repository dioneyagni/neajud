require "rails_helper"

# Etapa 1.2 (2/3): an arte is one envelope of files, one per part × size.
RSpec.describe "Arte files", type: :request do
  around do |example|
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = :inline
  end

  let(:tif) { Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/02-no_spot.tif"), "image/tiff") }
  let(:client) { create(:client) }
  let(:molde) { create(:molde, client: client) }

  describe "the gallery" do
    it "shows one card per arte, with its files' parts and sizes" do
      primeiro = create(:arquivo, filename: "19-BLUEY-29_30", tamanho_rotulo: "29-30")
      create(:arquivo, arte: primeiro.arte, filename: "19-BLUEY-31_32", tamanho_rotulo: "31-32")
      create(:arquivo, filename: "sozinha")

      get arquivos_path
      expect(response.body.scan('class="stamp-card"').size).to eq(2)
      expect(response.body).to include("19-BLUEY-29_30", "2 files · No part 29-30, 31-32", "sozinha")
      expect(response.body).not_to include("19-BLUEY-31_32")
    end

    it "batch delete trashes the whole arte of a card" do
      primeiro = create(:arquivo)
      outro = create(:arquivo, arte: primeiro.arte)
      delete batch_destroy_arquivos_path, params: { ids: [ primeiro.uuid ] }, as: :json
      expect([ primeiro.reload, outro.reload ].map(&:excluido?)).to eq([ true, true ])
    end
  end

  describe "the arte page" do
    it "lists every file of the arte by part, the open one marked" do
      lateral = create(:peca, nome: "Lateral")
      arquivo = create(:arquivo, filename: "a-29_30", peca: lateral, tamanho_rotulo: "29-30")
      outro = create(:arquivo, arte: arquivo.arte, filename: "a-31_32", peca: lateral, tamanho_rotulo: "31-32")
      get arquivo_path(arquivo)
      expect(response.body).to include("Files of this arte", "a-29_30.tif (this file)", arquivo_path(outro), separar_arquivo_arte_path(outro))
    end

    it "offers to join the same arte uploaded apart in another size" do
      referencia = Referencia.do_molde!(molde, "19")
      arquivo = create(:arquivo, molde: molde, referencia: referencia, nome: "Bluey")
      outra = create(:arquivo, molde: molde, referencia: referencia, nome: "bluey")
      get arquivo_path(arquivo)
      expect(response.body).to include("looks like this same arte in other sizes", %(value="#{outra.uuid}"))
    end
  end

  describe "POST acrescentar" do
    it "adds a file of the molde's part and size to the arte, sharing its fields" do
      peca = create(:peca)
      corte = create(:arquivo, :corte, organized: true, client: client, modelo: molde.modelo, peca: peca).tap { |c| c.moldes << molde }
      tamanho = create(:tamanho, arquivo: corte, nome: "31-32")
      arquivo = create(:arquivo, molde: molde, nome: "Bluey")

      expect { post acrescentar_arquivo_arte_path(arquivo), params: { original_file: tif, tamanho_uuid: tamanho.uuid } }
        .to have_enqueued_job(ArquivoProcessingJob)
      novo = Arquivo.order(:id).last
      expect([ novo.arte_id, novo.tamanho, novo.molde_id, novo.client_id, novo.nome, novo.resolved_peca ])
        .to eq([ arquivo.arte_id, tamanho, molde.id, client.id, "Bluey", peca ])
      expect(flash[:notice]).to include("added to this arte (31-32)")
    end

    it "takes a typed size and part while the arte has no molde" do
      peca = create(:peca)
      arquivo = create(:arquivo)
      post acrescentar_arquivo_arte_path(arquivo), params: { original_file: tif, peca_uuid: peca.uuid, tamanho_rotulo: " P " }
      expect(Arquivo.order(:id).last.attributes.values_at("arte_id", "peca_id", "tamanho_rotulo")).to eq([ arquivo.arte_id, peca.id, "P" ])
    end

    it "refuses a size of another molde's corte" do
      alheio = create(:tamanho, arquivo: create(:arquivo, :corte, organized: true))
      arquivo = create(:arquivo, molde: molde)
      post acrescentar_arquivo_arte_path(arquivo), params: { original_file: tif, tamanho_uuid: alheio.uuid }
      expect(response).to have_http_status(:not_found)
    end

    it "refuses a file that isn't an arte (a DXF), saving nothing" do
      dxf = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/29-30.dxf"), "image/vnd.dxf")
      arquivo = create(:arquivo)
      expect { post acrescentar_arquivo_arte_path(arquivo), params: { original_file: dxf } }.not_to change(Arquivo, :count)
      expect(flash[:alert]).to include("29-30.dxf is not an arte file; expected one of tif")
    end
  end

  describe "POST juntar and separar" do
    it "joins this arte into the chosen one and opens it" do
      destino = create(:arquivo, molde: molde)
      origem = create(:arquivo)
      post juntar_arquivo_arte_path(origem), params: { destino_uuid: destino.uuid }
      expect(response).to redirect_to(arquivo_path(destino))
      expect([ origem.reload.arte_id, origem.molde_id ]).to eq([ destino.arte_id, molde.id ])
    end

    it "explains a refused join on the arte's page" do
      origem = create(:arquivo, molde: molde)
      post juntar_arquivo_arte_path(origem), params: { destino_uuid: create(:arquivo, molde: create(:molde)).uuid }
      expect([ response, flash[:alert] ]).to match([ redirect_to(arquivo_path(origem)), /expected the same molde/ ])
    end

    it "takes a file out into an arte of its own, and refuses the only file" do
      arquivo = create(:arquivo)
      outro = create(:arquivo, arte: arquivo.arte)
      post separar_arquivo_arte_path(outro)
      expect(outro.reload.arte_id).not_to eq(arquivo.arte_id)
      post separar_arquivo_arte_path(outro)
      expect(flash[:alert]).to include("only file of its arte")
    end
  end

  it "the upload reads the size from the file name" do
    upload = Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files/02-no_spot.tif"), "image/tiff", original_filename: "20-base-29_30.tif")
    post arquivos_path, params: { arquivo: { original_file: upload } }
    expect(Arquivo.order(:id).last.attributes.values_at("tamanho_rotulo", "arte_id")).to match([ "29-30", be_present ])
  end
end
