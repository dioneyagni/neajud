require "rails_helper"

RSpec.describe "Tamanhos", type: :request do
  describe "GET /tamanhos/:id/download" do
    it "returns not_found when tamanho has no approved version" do
      arquivo = create(:arquivo)
      tamanho = create(:tamanho, arquivo: arquivo, nome: "Piloto", position: 1, width_mm: 100, height_mm: 50)

      get download_tamanho_path(tamanho)
      expect(response).to have_http_status(:not_found)
    end

    it "downloads a DXF file for a tamanho" do
      arquivo = create(:arquivo, extension: "dxf")
      version = create(:arquivo_version, arquivo: arquivo, approved: true, extension: "dxf", original_file: "original.dxf")
      arquivo.update!(approved_version_id: version.id)
      tamanho = create(:tamanho, arquivo: arquivo, nome: "Piloto", position: 1, width_mm: 100, height_mm: 50)

      original_dir = File.join(version.storage_dir, "original")
      FileUtils.mkdir_p(original_dir)
      dxf_content = "0\nSECTION\n2\nHEADER\n9\n$INSUNITS\n70\n4\n0\nENDSEC\n0\nSECTION\n2\nENTITIES\n0\nLWPOLYLINE\n5\nA1\n8\n0\n90\n4\n70\n1\n10\n0\n20\n0\n10\n100\n20\n0\n10\n100\n20\n100\n10\n0\n20\n100\n0\nENDSEC\n0\nEOF\n"
      File.write(File.join(original_dir, "original.dxf"), dxf_content)

      get download_tamanho_path(tamanho)
      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Disposition"]).to include("Piloto.dxf")
    end

    # Regression (#97): the extract path used tamanho.nome (free text), so a
    # nome like "../../x" wrote and served a file outside the extracts folder.
    # Since Etapa 0.6 the extract lives in the version's tamanho_previews/.
    it "keeps the extract in the version's folder, named by position, whatever the nome is" do
      arquivo = create(:arquivo, extension: "dxf", filename: "corte")
      version = create(:arquivo_version, arquivo: arquivo, approved: true, extension: "dxf", original_file: "36 ao 48.dxf")
      arquivo.update!(approved_version_id: version.id)
      FileUtils.mkdir_p(File.join(version.storage_dir, "original"))
      FileUtils.cp(Rails.root.join("spec/fixtures/files/36 ao 48.dxf"), File.join(version.storage_dir, "original", "36 ao 48.dxf"))
      evil = arquivo.tamanhos.create!(nome: "../../../evil", position: 1, width_mm: 1, height_mm: 1)
      outside = Rails.root.join("evil.dxf")

      get download_tamanho_path(evil)

      expect(response).to have_http_status(:success)
      expect(File.exist?(outside)).to be false
      expect(File.exist?(File.join(version.storage_dir, "tamanho_previews", "1.dxf"))).to be true
    ensure
      FileUtils.rm_f(outside)
      FileUtils.rm_rf(File.join(ArquivoVersion::STORAGE_BASE, arquivo.uuid)) if arquivo
    end

    it "downloads DXF with INSERT entities (block references)" do
      arquivo = create(:arquivo, extension: "dxf", filename: "36 ao 48")
      version = create(:arquivo_version, arquivo: arquivo, approved: true, extension: "dxf",
        original_file: "36 ao 48.dxf")
      arquivo.update!(approved_version_id: version.id)

      original_dir = File.join(version.storage_dir, "original")
      FileUtils.mkdir_p(original_dir)
      src = Rails.root.join("spec/fixtures/files/36 ao 48.dxf").to_s
      FileUtils.cp(src, File.join(original_dir, "36 ao 48.dxf"))

      arquivo.tamanhos.destroy_all
      arquivo.tamanhos.create!(nome: "36", position: 1, width_mm: 412.24, height_mm: 88.67, area_mm2: 30096.96)
      tamanho = arquivo.tamanhos.first

      get download_tamanho_path(tamanho)
      expect(response).to have_http_status(:success)
      expect(response.headers["Content-Disposition"]).to include("36 ao 48 - 36.dxf")
      expect(response.headers["Content-Type"]).to include("application/dxf")

      FileUtils.rm_rf(File.join(ArquivoVersion::STORAGE_BASE, arquivo.uuid))
      arquivo.destroy!
    end
  end

  # The sizes of the molde's own cortes of one piece (Arquivo.cortes_do_molde).
  describe "GET /tamanhos/for_cascade" do
    let(:molde) { create(:molde) }
    let(:peca) { create(:peca) }

    def corte(molde: self.molde, **attrs)
      create(:arquivo, :corte, organized: true, peca: peca, client: molde.client, modelo: molde.modelo, **attrs).tap { |c| c.moldes << molde }
    end

    it "returns the sizes of the molde's corte of that piece, regardless of tipo_corte, as JSON" do
      create(:tamanho, arquivo: corte(tipo_corte: "apenas_corte"), nome: "G", position: 1, width_mm: 100, height_mm: 50)
      get for_cascade_tamanhos_path, params: { molde_uuid: molde.uuid, peca_uuid: peca.uuid }
      expect(response.parsed_body.map { |t| t.values_at("nome", "width", "height") }).to eq([ [ "G", "100.0", "50.0" ] ])
    end

    # Regression (01/10/2026): see pecas_spec — the corte kept another category.
    it "finds the molde's corte whatever its category, and not another molde's" do
      create(:tamanho, arquivo: corte(modelo: create(:modelo)), nome: "29-30")
      create(:tamanho, arquivo: corte(molde: create(:molde, client: molde.client, modelo: molde.modelo)), nome: "31-32")
      get for_cascade_tamanhos_path, params: { molde_uuid: molde.uuid, peca_uuid: peca.uuid }
      expect(response.parsed_body.map { |t| t["nome"] }).to eq([ "29-30" ])
    end

    it "returns an empty array when nothing matches" do
      get for_cascade_tamanhos_path, params: { molde_uuid: "nao-existe", peca_uuid: "nao-existe" }
      expect(response.parsed_body).to eq([])
    end
  end

  describe "INSERT entity DXF extraction" do
    it "extracts each tamanho from a DXF with INSERT entities and block references" do
      arquivo = create(:arquivo, extension: "dxf", filename: "36 ao 48")
      version = create(:arquivo_version, arquivo: arquivo, approved: true, extension: "dxf",
        original_file: "36 ao 48.dxf")
      arquivo.update!(approved_version_id: version.id)

      original_dir = File.join(version.storage_dir, "original")
      FileUtils.mkdir_p(original_dir)
      src = Rails.root.join("spec/fixtures/files/36 ao 48.dxf").to_s
      FileUtils.cp(src, File.join(original_dir, "36 ao 48.dxf"))

      DxfOrganizationService.call(arquivo)
      arquivo.reload

      expect(arquivo.tamanhos.count).to eq(7)
      expect(arquivo.tamanhos.first.nome).to eq("36")
      expect(arquivo.tamanhos.last.nome).to eq("48")
      expect(arquivo.tamanhos.first.position).to eq(1)
      expect(arquivo.tamanhos.last.position).to eq(7)

      arquivo.tamanhos.each do |t|
        output_path = Rails.root.join("tmp", "tamanho_extract_test", arquivo.uuid, "#{t.nome}.dxf")
        FileUtils.mkdir_p(output_path.dirname)
        result = system("node", Rails.root.join("bin", "extract-tamanho-dxf.js").to_s,
          version.original_path.to_s, output_path.to_s, t.position.to_s,
          out: File::NULL, err: File::NULL)
        expect(result).to be true
      end

      FileUtils.rm_rf(File.join(ArquivoVersion::STORAGE_BASE, arquivo.uuid))
      FileUtils.rm_rf(Rails.root.join("tmp", "tamanho_extracts", arquivo.uuid))
      arquivo.destroy!
    end

    describe "the DXF prepared by PreparacaoTamanhosJob (Etapa 0.6)" do
      let(:arquivo) { create(:arquivo, extension: "dxf", filename: "corte") }
      let(:version) do
        create(:arquivo_version, arquivo: arquivo, approved: true, extension: "dxf", original_file: "36 ao 48.dxf").tap do |v|
          arquivo.update!(approved_version_id: v.id)
          FileUtils.mkdir_p(File.join(v.storage_dir, "original"))
          FileUtils.cp(Rails.root.join("spec/fixtures/files/36 ao 48.dxf"), v.original_path)
        end
      end
      let(:tamanho) { arquivo.tamanhos.create!(nome: "36", position: 1, width_mm: 1, height_mm: 1) }

      after { FileUtils.rm_rf(File.join(ArquivoVersion::STORAGE_BASE, arquivo.uuid)) }

      it "serves the prepared file without extracting again" do
        caminho = tamanho.dxf_extraido_path(version)
        FileUtils.mkdir_p(File.dirname(caminho))
        File.write(caminho, "PREPARED")
        get download_tamanho_path(tamanho)
        expect(response.body).to eq("PREPARED")
      end

      it "extracts again when the prepared file is older than the corte's version" do
        caminho = tamanho.dxf_extraido_path(version)
        FileUtils.mkdir_p(File.dirname(caminho))
        File.write(caminho, "STALE")
        File.utime(Time.now - 3600, Time.now - 3600, caminho)
        get download_tamanho_path(tamanho)
        expect(response.body).not_to eq("STALE")
        expect(response.body).to include("SECTION")
      end
    end
  end
end
