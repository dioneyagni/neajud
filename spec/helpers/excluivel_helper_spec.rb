require "rails_helper"

RSpec.describe ExcluivelHelper, type: :helper do
  it "renders the badge with the deletion date for a trashed record" do
    client = create(:client, deleted_at: Time.zone.local(2026, 9, 20, 10))
    expect(helper.selo_excluido(client)).to include("excluído em 20/09/2026", 'class="badge-excluido"')
  end

  it "renders nothing for active records and nil" do
    expect(helper.selo_excluido(create(:client))).to be_nil
    expect(helper.selo_excluido(nil)).to be_nil
  end

  describe "#miniatura_lixeira" do
    # A preview file on disk for the arte's approved version.
    def arte_com_preview_no_disco
      arte = create(:arquivo, extension: "tif")
      preview = ArquivoVersion::STORAGE_BASE.join(arte.uuid, "preview.png")
      FileUtils.mkdir_p(preview.dirname)
      File.write(preview, "png")
      version = create(:arquivo_version, arquivo: arte, version_number: 1, status: :processed, preview_file: preview.to_s)
      arte.tap { |a| a.update!(approved_version: version) }
    end

    it "shows the arte preview" do
      arte = arte_com_preview_no_disco
      expect(helper.miniatura_lixeira(arte)).to include(preview_arquivo_path(arte), 'class="lixeira-thumb"')
    end

    it "shows a pedido's first arte preview" do
      arte = arte_com_preview_no_disco
      pedido = create(:pedido).tap { |p| create(:item_pedido, pedido: p, arquivo: arte) }
      expect(helper.miniatura_lixeira(pedido)).to include(preview_arquivo_path(arte))
    end

    it "falls back to the extension icon when the arte has no preview" do
      expect(helper.miniatura_lixeira(create(:arquivo, extension: "dxf"))).to include("icons/extensions/dxf", "lixeira-thumb--icone")
    end

    it "uses the type icon for records without previews" do
      expect(helper.miniatura_lixeira(create(:client))).to include("icons/lixeira/client")
      expect(helper.miniatura_lixeira(create(:pedido))).to include("icons/lixeira/pedido")
      expect(helper.miniatura_lixeira(create(:peca))).to include("icons/lixeira/peca")
    end
  end
end
