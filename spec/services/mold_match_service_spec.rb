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

  def corte_with_tamanhos(modelo_id:, tamanhos: [], preview_filename: "corte.png", client_id: nil)
    corte = create(:arquivo, category: "corte", extension: "dxf", organized: true,
      modelo_id: modelo_id, client_id: client_id)
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
      it "returns nil when arte has no molde.modelo and no client" do
        arte = arte_with_preview
        expect(described_class.call(arte)).to be_nil
      end
    end

    context "when all candidate cortes are filtered by dimension prefilter" do
      it "returns nil when all cortes have incompatible aspect ratios" do
        modelo = create(:modelo)
        client = create(:client)
        arte = arte_with_preview
        arte.update!(client_id: client.id)
        molde = create(:molde, modelo: modelo, client: client)
        arte.update!(molde_id: molde.id)
        arte.reload

        corte_with_tamanhos(modelo_id: modelo.id, preview_filename: "corte-bad-ratio.png",
          tamanhos: [
            { nome: "T1", width_mm: 500, height_mm: 10 }
          ])

        expect(described_class.call(arte)).to be_nil
      end
    end

    # Regression (28/09/2026): a modelo shared by several moldes, each with its
    # own corte. An arte of molde 28-29 got the tamanho of 21-24's corte,
    # which matched better — it must only look at its molde's cortes.
    context "when the modelo is shared by several moldes" do
      it "only considers the cortes linked to the arte's molde" do
        modelo = create(:modelo)
        client = create(:client)
        outro_molde = create(:molde, modelo: modelo, client: client, nome: "21-24")
        molde = create(:molde, modelo: modelo, client: client, nome: "28-29")
        arte = arte_with_preview
        arte.update!(client_id: client.id, molde_id: molde.id)

        do_outro = corte_with_tamanhos(modelo_id: modelo.id, preview_filename: "outro.png",
          tamanhos: [ { nome: "Exato do outro", width_mm: 100, height_mm: 50 } ])
        do_outro.moldes << outro_molde
        do_meu = corte_with_tamanhos(modelo_id: modelo.id, preview_filename: "meu.png",
          tamanhos: [ { nome: "Do meu molde", width_mm: 106, height_mm: 53 } ])
        do_meu.moldes << molde

        expect(described_class.call(arte.reload).nome).to eq("Do meu molde")
      end
    end

    context "when dimensions match" do
      it "returns the tamanho with closest dimensions" do
        modelo = create(:modelo)
        client = create(:client)
        arte = arte_with_preview
        arte.update!(client_id: client.id)
        molde = create(:molde, modelo: modelo, client: client)
        arte.update!(molde_id: molde.id)
        arte.reload

        corte_with_tamanhos(modelo_id: modelo.id, client_id: client.id, preview_filename: "corte-dims.png",
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
        modelo = create(:modelo)
        client = create(:client)
        arte = arte_with_preview
        arte.update!(client_id: client.id)
        molde = create(:molde, modelo: modelo, client: client)
        arte.update!(molde_id: molde.id)
        arte.reload

        t_preview = arte.preview_file

        corte_with_tamanhos(modelo_id: modelo.id, client_id: client.id, preview_filename: "corte-contour-fallback.png",
          tamanhos: [
            { nome: "ContourMatch", width_mm: 200, height_mm: 100,
              preview_file: t_preview }
          ])

        result = described_class.call(arte)
        expect(result).to be_present
        expect(result.nome).to eq("ContourMatch")
      end
    end

    context "when no molde.modelo but client has modelos" do
      it "finds corticales via client-level fallback" do
        client = create(:client)
        modelo = create(:modelo)
        create(:molde, modelo: modelo, client: client)

        arte = arte_with_preview
        arte.update!(client_id: client.id)
        arte.reload

        t_preview = arte.preview_file
        corte_with_tamanhos(modelo_id: modelo.id, client_id: client.id, preview_filename: "corte-client-fallback.png",
          tamanhos: [
            { nome: "ClientFallback", width_mm: 100, height_mm: 50,
              preview_file: t_preview }
          ])

        result = described_class.call(arte)
        expect(result).to be_present
        expect(result.nome).to eq("ClientFallback")
      end

      # Regression (Etapa 1.1, 3/5): the official "Tenis" is every client's
      # modelo, so the fallback matched another client's corte.
      it "never takes another client's corte of the same modelo" do
        client = create(:client)
        modelo = create(:modelo)
        create(:molde, modelo: modelo, client: client)
        arte = arte_with_preview
        arte.update!(client_id: client.id)
        arte.reload

        corte_with_tamanhos(modelo_id: modelo.id, client_id: create(:client).id, preview_filename: "corte-outro-cliente.png",
          tamanhos: [ { nome: "OutroCliente", width_mm: 100, height_mm: 50, preview_file: arte.preview_file } ])

        expect(described_class.call(arte)).to be_nil
      end
    end

    context "mold-level contour comparison" do
      it "rejects cortes whose full outline is too different from arte outline" do
        modelo = create(:modelo)
        client = create(:client)
        arte = arte_with_preview
        arte.update!(client_id: client.id)
        molde = create(:molde, modelo: modelo, client: client)
        arte.update!(molde_id: molde.id)
        arte.reload

        t_preview = arte.preview_file

        corte_with_tamanhos(modelo_id: modelo.id, client_id: client.id, preview_filename: "corte-bad-mold.png",
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
