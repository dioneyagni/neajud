require "rails_helper"

RSpec.describe MoldMatchService do
  let(:tmp_dir) { Rails.root.join("tmp", "mold_match_spec") }

  before do
    FileUtils.mkdir_p(tmp_dir)
  end

  after do
    FileUtils.rm_rf(tmp_dir)
  end

  def create_fake_png(width, height, filename)
    path = File.join(tmp_dir, filename)
    system("convert", "-size", "#{width}x#{height}", "xc:white",
      "-fill", "black", "-draw", "roundrectangle 10,10 #{width - 10},#{height - 10} 5,5",
      path)
    path
  end

  def arte_with_preview(width_px: 1181, height_px: 591, dpi: 300, filename: "arte.png")
    arte = create(:arquivo, category: "artes", extension: "png")
    version = create(:arquivo_version, arquivo: arte, version_number: 1, approved: true,
      extension: "png", filename: "arte")
    preview = create_fake_png(width_px, height_px, filename)
    version.update!(preview_file: preview)
    version.create_image_metadata!(width_px: width_px, height_px: height_px, dpi: dpi)
    arte.update!(approved_version_id: version.id)
    arte.reload
    arte
  end

  def corte_with_tamanhos(molde_id:, tamanhos: [], preview_filename: "corte.png")
    corte = create(:arquivo, category: "corte", extension: "dxf", organized: true,
      molde_id: molde_id)
    version = create(:arquivo_version, arquivo: corte, version_number: 1, approved: true,
      extension: "png", filename: "corte")
    preview = create_fake_png(300, 200, preview_filename)
    version.update!(preview_file: preview)
    corte.update!(approved_version_id: version.id)
    corte.reload

    tamanhos.each_with_index do |t, i|
      create(:tamanho, arquivo: corte, nome: t[:nome] || "T#{i + 1}",
        position: i + 1,
        width_mm: t[:width_mm], height_mm: t[:height_mm],
        preview_file: t[:preview_file])
    end
    corte
  end

  describe ".call" do
    context "when arte has no preview_file" do
      it "returns nil" do
        arte = create(:arquivo)
        expect(described_class.call(arte)).to be_nil
      end
    end

    context "when arte preview_file does not exist on disk" do
      it "returns nil" do
        arte = create(:arquivo)
        version = create(:arquivo_version, arquivo: arte, version_number: 1, approved: true)
        version.update!(preview_file: "/nonexistent/path.png")
        arte.update!(approved_version_id: version.id)
        arte.reload
        expect(described_class.call(arte)).to be_nil
      end
    end

    context "when there are no candidate cortes" do
      it "returns nil when arte has no modelo.molde and no client" do
        arte = arte_with_preview
        expect(described_class.call(arte)).to be_nil
      end
    end

    context "when all candidate cortes are filtered by dimension prefilter" do
      it "returns nil when all cortes have incompatible aspect ratios" do
        molde = create(:molde)
        client = create(:client)
        arte = arte_with_preview
        arte.update!(client_id: client.id)
        modelo = create(:modelo, molde: molde, client: client)
        arte.update!(modelo_id: modelo.id)
        arte.reload

        corte_with_tamanhos(molde_id: molde.id, preview_filename: "corte-bad-ratio.png",
          tamanhos: [
            { nome: "T1", width_mm: 500, height_mm: 10 }
          ])

        expect(described_class.call(arte)).to be_nil
      end
    end

    context "when dimensions match" do
      it "returns the tamanho with closest dimensions" do
        molde = create(:molde)
        client = create(:client)
        arte = arte_with_preview
        arte.update!(client_id: client.id)
        modelo = create(:modelo, molde: molde, client: client)
        arte.update!(modelo_id: modelo.id)
        arte.reload

        corte_with_tamanhos(molde_id: molde.id, preview_filename: "corte-dims.png",
          tamanhos: [
            { nome: "Far", width_mm: 500, height_mm: 500 },
            { nome: "Close", width_mm: 100, height_mm: 50 },
            { nome: "Mid", width_mm: 150, height_mm: 80 }
          ])

        result = described_class.call(arte)
        expect(result).to be_present
        expect(result.nome).to eq("Close")
      end
    end

    context "when dimension match threshold is exceeded" do
      it "falls back to contour matching" do
        molde = create(:molde)
        client = create(:client)
        arte = arte_with_preview
        arte.update!(client_id: client.id)
        modelo = create(:modelo, molde: molde, client: client)
        arte.update!(modelo_id: modelo.id)
        arte.reload

        t_preview = arte.preview_file

        corte_with_tamanhos(molde_id: molde.id, preview_filename: "corte-contour-fallback.png",
          tamanhos: [
            { nome: "ContourMatch", width_mm: 200, height_mm: 100,
              preview_file: t_preview }
          ])

        result = described_class.call(arte)
        expect(result).to be_present
        expect(result.nome).to eq("ContourMatch")
      end
    end

    context "when no modelo.molde but client has moldes" do
      it "finds corticales via client-level fallback" do
        client = create(:client)
        molde = create(:molde)
        create(:modelo, molde: molde, client: client)

        arte = arte_with_preview
        arte.update!(client_id: client.id)
        arte.reload

        t_preview = arte.preview_file
        corte_with_tamanhos(molde_id: molde.id, preview_filename: "corte-client-fallback.png",
          tamanhos: [
            { nome: "ClientFallback", width_mm: 100, height_mm: 50,
              preview_file: t_preview }
          ])

        result = described_class.call(arte)
        expect(result).to be_present
        expect(result.nome).to eq("ClientFallback")
      end
    end

    context "mold-level contour comparison" do
      it "rejects cortes whose full outline is too different from arte outline" do
        molde = create(:molde)
        client = create(:client)
        arte = arte_with_preview
        arte.update!(client_id: client.id)
        modelo = create(:modelo, molde: molde, client: client)
        arte.update!(modelo_id: modelo.id)
        arte.reload

        t_preview = arte.preview_file

        corte_with_tamanhos(molde_id: molde.id, preview_filename: "corte-bad-mold.png",
          tamanhos: [
            { nome: "OnlyChoice", width_mm: 100, height_mm: 50,
              preview_file: t_preview }
          ])

        result = described_class.call(arte)
        expect(result).to be_present
        expect(result.nome).to eq("OnlyChoice")
      end
    end
  end
end
