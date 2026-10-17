require "rails_helper"

RSpec.describe ItemPedido, type: :model do
  subject(:item) { build(:item_pedido) }

  describe "validations" do
    it "validates uuid uniqueness" do
      item.save!
      dup = build(:item_pedido, uuid: item.uuid)
      expect(dup).not_to be_valid
      expect(dup.errors[:uuid]).to include(/already been taken/i)
    end
  end

  describe "associations" do
    it { should belong_to(:pedido) }
    it { should belong_to(:arquivo) }
    it { should belong_to(:materia_prima).optional }
    it { should have_many(:grades).dependent(:destroy) }
  end

  describe "callbacks" do
    it "generates uuid before create" do
      item.save!
      expect(item.uuid).to be_present
      expect(item.uuid).to match(/\A[0-9a-f-]{36}\z/)
    end
  end

  describe "#to_param" do
    it "returns uuid" do
      item.save!
      expect(item.to_param).to eq(item.uuid)
    end
  end

  describe "#quantidade_total" do
    it "sums grade quantities" do
      item.save!
      create(:item_pedido_grade, item_pedido: item, quantidade: 4)
      create(:item_pedido_grade, item_pedido: item, tamanho_nome: "Tam X", quantidade: 1)
      expect(item.quantidade_total).to eq(5)
    end

    it "returns 0 when no grades" do
      item.save!
      expect(item.quantidade_total).to eq(0)
    end
  end

  describe "#compor_pecas!" do
    it "stores one row per slot, in order, all checked" do
      item = create(:item_pedido)
      lateral, lingua = create(:peca), create(:peca)
      slots = [
        MoldeComposicaoService::Slot.new(peca: lateral, arquivo: item.arquivo),
        MoldeComposicaoService::Slot.new(peca: lingua, arquivo: nil)
      ]
      item.compor_pecas!(slots)
      rows = item.item_pedido_pecas.reload
      expect(rows.map { |r| [ r.peca, r.arquivo, r.position, r.estado ] })
        .to eq([ [ lateral, item.arquivo, 0, :incluida ], [ lingua, nil, 1, :incluida ] ])
    end
  end

  describe "#copiar_pecas_de!" do
    it "copies pieces with their checked/unchecked state" do
      source = create(:item_pedido)
      create(:item_pedido_peca, item_pedido: source, incluida: false, position: 0)
      create(:item_pedido_peca, item_pedido: source, arquivo: nil, position: 1)
      copy = create(:item_pedido)
      copy.copiar_pecas_de!(source)
      expect(copy.item_pedido_pecas.reload.map(&:estado)).to eq([ :excluida, :incluida ])
    end
  end

  describe "#excluir_pecas!" do
    it "unchecks only the pieces whose arte uuid was given, ignoring unknown uuids" do
      item = create(:item_pedido)
      kept = create(:item_pedido_peca, item_pedido: item, position: 0)
      dropped = create(:item_pedido_peca, item_pedido: item, position: 1)
      pending = create(:item_pedido_peca, item_pedido: item, arquivo: nil, position: 2)
      item.excluir_pecas!([ dropped.arquivo.uuid, "unknown" ])
      expect([ kept, dropped, pending ].map { |r| r.reload.estado }).to eq([ :incluida, :excluida, :incluida ])
    end

    it "does nothing when no uuids are given" do
      item = create(:item_pedido)
      row = create(:item_pedido_peca, item_pedido: item)
      item.excluir_pecas!(nil)
      expect(row.reload.estado).to eq(:incluida)
    end
  end

  # Etapa 2.7a (decided 16/10/2026): a tecido item's meters and width.
  describe "a tecido item" do
    let(:tecido) { MateriaPrima.create!(grupo_material: GrupoMaterial.create!(nome: "Oxford"), cor_material: CorMaterial.create!(nome: "Azul"), largura: "1.60", gramatura: "1g") }

    it "takes meters with one decimal, never two nor negative" do
      expect([ "12.5", "3" ].map { |m| build(:item_pedido, metros: m).valid? }).to eq([ true, true ])
      expect(build(:item_pedido, metros: "12.55").tap(&:validate).errors[:metros]).to eq([ "12.55 has more than one decimal; expected meters like 12,5" ])
      expect(build(:item_pedido, metros: "-1")).not_to be_valid
    end

    it "is printed on the width typed, else the material's" do
      item = build(:item_pedido, materia_prima: tecido)
      expect(item.largura_efetiva_mm).to eq(1600)
      item.largura_mm = 1400
      expect(item.largura_efetiva_mm).to eq(1400)
      expect(build(:item_pedido).largura_efetiva_mm).to be_nil
    end
  end
end
