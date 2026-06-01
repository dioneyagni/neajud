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
      expect(response.headers["Content-Disposition"]).to include("36.dxf")
      expect(response.headers["Content-Type"]).to include("application/dxf")

      FileUtils.rm_rf(File.join(Rails.root, "storage", "stamps", arquivo.uuid))
      arquivo.destroy!
    end
  end

  describe "GET /tamanhos/for_cascade" do
    it "returns tamanhos as JSON for given molde_id and peca_id" do
      molde = create(:molde)
      peca = create(:peca)
      arquivo = create(:arquivo, organized: true, molde: molde, peca: peca)
      tamanho = create(:tamanho, arquivo: arquivo, nome: "G", position: 1, width_mm: 100, height_mm: 50)

      get for_cascade_tamanhos_path, params: { molde_id: molde.id, peca_id: peca.id }
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to be_an(Array)
      expect(json.first["nome"]).to eq("G")
    end

    it "returns empty array when no matching tamanhos" do
      get for_cascade_tamanhos_path, params: { molde_id: 99999, peca_id: 99999 }
      expect(response).to have_http_status(:success)
      json = JSON.parse(response.body)
      expect(json).to eq([])
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

      FileUtils.rm_rf(File.join(Rails.root, "storage", "stamps", arquivo.uuid))
      FileUtils.rm_rf(Rails.root.join("tmp", "tamanho_extracts", arquivo.uuid))
      arquivo.destroy!
    end
  end
end
