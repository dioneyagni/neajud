require "rails_helper"

RSpec.describe VincularArteService do
  let(:client) { create(:client) }
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:lingua) { create(:peca, nome: "Língua") }
  let(:molde) { create(:molde, client: client, nome: "Tênis baixo") }

  def pending_row_in(pedido)
    item = create(:item_pedido, pedido: pedido, arquivo: create(:arquivo, client: client, molde: molde, peca: lateral))
    create(:item_pedido_peca, item_pedido: item, peca: lingua, arquivo: nil)
  end

  let(:pedido) { create(:pedido) }
  let(:pending_row) { pending_row_in(pedido) }

  def vincular(arte, confirmar_mudanca: false, row: pending_row)
    described_class.call(row, arte, changed_by: "127.0.0.1", confirmar_mudanca: confirmar_mudanca)
  end

  it "links an arte without molde to the molde, peça and client, and fills the piece" do
    arte = create(:arquivo, client: nil)
    vincular(arte)
    expect(arte.reload.slice(:molde_id, :peca_id, :client_id).values).to eq([ molde.id, lingua.id, client.id ])
    expect(pending_row.reload.estado).to eq(:incluida)
    expect(pending_row.arquivo).to eq(arte)
  end

  it "logs the link without a from_molde when the arte had none" do
    arte = create(:arquivo, client: client)
    vincular(arte)
    log = arte.vinculo_logs.sole
    expect([ log.from_molde_nome, log.to_molde_nome, log.peca, log.pedido, log.changed_by, log.mudanca? ])
      .to eq([ nil, "Tênis baixo", lingua, pedido, "127.0.0.1", false ])
  end

  it "refuses to move an arte from another molde without confirmation, changing nothing" do
    other = create(:molde, client: client, nome: "Outro")
    arte = create(:arquivo, client: client, molde: other)
    expect { vincular(arte) }.to raise_error(described_class::NaoConfirmado, /"Outro".*"Tênis baixo"/)
    expect([ arte.reload.molde_id, pending_row.reload.estado, ArquivoVinculoLog.count ]).to eq([ other.id, :pendente, 0 ])
  end

  it "moves it when confirmed and logs where it came from" do
    other = create(:molde, client: client, nome: "Outro")
    arte = create(:arquivo, client: client, molde: other)
    vincular(arte, confirmar_mudanca: true)
    log = arte.vinculo_logs.sole
    expect([ arte.reload.molde_id, log.from_molde, log.from_molde_nome, log.mudanca? ]).to eq([ molde.id, other, "Outro", true ])
  end

  it "fills the same pending peça in other draft pedidos of the molde, not in confirmed ones" do
    other_draft = pending_row_in(create(:pedido))
    confirmed = pending_row_in(create(:pedido, status: "confirmado"))
    arte = create(:arquivo, client: client)
    vincular(arte)
    expect([ other_draft.reload.arquivo, confirmed.reload.arquivo ]).to eq([ arte, nil ])
  end

  it "refuses an arte that is not a candidate" do
    expect { vincular(create(:arquivo, client: create(:client))) }.to raise_error(described_class::Recusado, /not a candidate/)
  end

  it "refuses a piece that is not pending" do
    filled = create(:item_pedido_peca, item_pedido: pending_row.item_pedido, peca: create(:peca))
    expect { vincular(create(:arquivo), row: filled) }.to raise_error(described_class::Recusado, /not pending/)
  end
end
