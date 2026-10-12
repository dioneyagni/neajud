require "rails_helper"

RSpec.describe "Arquivo processing status broadcasts" do
  let(:arquivo) { create(:arquivo) }
  let!(:version) { create(:arquivo_version, arquivo: arquivo, status: "pending").tap { |v| arquivo.update!(approved_version: v) } }

  it "broadcasts when a version's status changes" do
    expect_any_instance_of(Arquivo).to receive(:broadcast_status_change)
    version.update!(status: "processing")
  end

  it "does not broadcast on other version updates" do
    expect_any_instance_of(Arquivo).not_to receive(:broadcast_status_change)
    version.update!(filename: "renamed")
  end

  it "when processing ends, replaces the gallery card and refreshes this arquivo's page and the pedidos using it" do
    version.update_column(:status, "processed")
    pedido = create(:pedido)
    allow(arquivo).to receive(:pedidos_que_usam).and_return([ pedido ])
    expect(arquivo).to receive(:broadcast_replace_to).with(CanaisAoVivo::EQUIPE, hash_including(target: "arquivo_#{arquivo.uuid}", partial: "arquivos/card"))
    expect(CanaisAoVivo).to receive(:recarregar).with(arquivo)
    expect(CanaisAoVivo).to receive(:recarregar).with(pedido)
    arquivo.reload.broadcast_status_change
  end

  it "while queued or processing, only replaces the gallery card (no page refresh mid-edit)" do
    version.update_column(:status, "processing")
    expect(arquivo).to receive(:broadcast_replace_to)
    expect(CanaisAoVivo).not_to receive(:recarregar)
    expect(arquivo).not_to receive(:pedidos_que_usam)
    arquivo.reload.broadcast_status_change
  end

  describe "#pedidos_que_usam" do
    it "finds pedidos using the arte as an item or as one of an item's pieces, once each" do
      as_item = create(:item_pedido, arquivo: arquivo).pedido
      as_piece = create(:item_pedido_peca, arquivo: arquivo).item_pedido.pedido
      both = create(:pedido)
      create(:item_pedido_peca, item_pedido: create(:item_pedido, pedido: both, arquivo: arquivo), arquivo: arquivo)
      create(:item_pedido)
      expect(arquivo.pedidos_que_usam).to contain_exactly(as_item, as_piece, both)
    end
  end

  # Regression: in the job, arquivo.approved_version was a different object than
  # the version being updated, so the broadcast still saw "processing" — the
  # gallery card never left "Processando" and no page refresh was sent.
  it "broadcasts the new status even when the arquivo cached another copy of the version" do
    job_version = ArquivoVersion.find(version.id)
    job_version.arquivo.approved_version.status # the job loads these before finishing
    seen = nil
    allow_any_instance_of(Arquivo).to receive(:broadcast_replace_to) { |a, *| seen = a.status }
    job_version.update!(status: "processed")
    expect(seen).to eq("processed")
  end
end
