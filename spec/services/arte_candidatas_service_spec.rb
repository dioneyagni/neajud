require "rails_helper"

RSpec.describe ArteCandidatasService do
  let(:client) { create(:client) }
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:lingua) { create(:peca, nome: "Língua") }
  let(:molde) { create(:molde, client: client, sufixo: "Tênis baixo") }
  let(:pending_row) do
    item = create(:item_pedido, arquivo: create(:arquivo, client: client, molde: molde, peca: lateral))
    create(:item_pedido_peca, item_pedido: item, peca: lingua, arquivo: nil)
  end

  def groups
    described_class.call(pending_row).to_h { |g| [ g.chave, g.artes ] }
  end

  it "returns the three groups in the agreed order" do
    expect(described_class.call(pending_row).map(&:chave)).to eq(%i[cliente_sem_peca cliente_sem_molde sem_cliente])
  end

  it "group 1: client's artes with a molde but no peça, this molde first" do
    other_molde = create(:molde, client: client, sufixo: "AAA outro")
    of_other = create(:arquivo, client: client, molde: other_molde, filename: "a-outro")
    of_this = create(:arquivo, client: client, molde: molde, filename: "z-este")
    create(:arquivo, client: client, molde: molde, peca: lateral)
    expect(groups[:cliente_sem_peca]).to eq([ of_this, of_other ])
  end

  it "group 2: client's artes without molde, without peça or already on the pending peça" do
    free = create(:arquivo, client: client, filename: "a-livre")
    on_lingua = create(:arquivo, client: client, peca: lingua, filename: "b-lingua")
    create(:arquivo, client: client, peca: lateral)
    expect(groups[:cliente_sem_molde]).to eq([ free, on_lingua ])
  end

  it "never offers an arte that is in the trash" do
    trashed = create(:arquivo, client: nil, filename: "na-lixeira")
    trashed.excluir!(changed_by: "10.0.0.1")
    expect(groups.values.flatten).not_to include(trashed)
  end

  it "group 3: artes without client" do
    orphan = create(:arquivo, client: nil)
    expect(groups[:sem_cliente]).to eq([ orphan ])
  end

  it "leaves out other clients' artes and cortes" do
    create(:arquivo, client: create(:client), filename: "outro-cliente")
    create(:arquivo, :corte, client: client)
    expect(groups.values.flatten).to be_empty
  end

  it "treats an arte whose corte gives it a peça as having that peça" do
    via_corte = create(:arquivo, client: client, tamanho: create(:tamanho, arquivo: create(:arquivo, :corte, peca: lateral)))
    expect(groups.values.flatten).not_to include(via_corte)
  end

  it "#candidata? answers for any group" do
    orphan = create(:arquivo, client: nil)
    other_client = create(:arquivo, client: create(:client))
    service = described_class.new(pending_row)
    expect([ service.candidata?(orphan), service.candidata?(other_client) ]).to eq([ true, false ])
  end
end
