require "rails_helper"

RSpec.describe Excluivel do
  let(:client) { create(:client, name: "Fagner") }

  describe "#excluir!" do
    it "marks the row, keeps it, and logs who did it" do
      client.excluir!(changed_by: "10.0.0.1")

      expect(Client.exists?(client.id)).to be true
      expect(client.reload).to be_excluido
      expect(client.exclusao_logs.last).to have_attributes(acao: "excluido", registro_rotulo: "Fagner", changed_by: "10.0.0.1")
    end

    # A legacy row that no longer passes today's validations must still be
    # deletable (update_columns, not update!).
    it "works on a record that fails validation" do
      client.update_columns(responsible: "")
      expect { client.excluir!(changed_by: "10.0.0.1") }.to change { client.reload.excluido? }.to(true)
    end
  end

  it "records who deleted and restored it (Etapa 0.5)" do
    ana, bia = create(:user), create(:user)
    client.excluir!(changed_by: "10.0.0.1", user: ana)
    expect(client.reload.deleted_by_id).to eq(ana.id)
    expect(client.exclusao_logs.last.user).to eq(ana)

    client.restaurar!(changed_by: "10.0.0.2", user: bia)
    expect(client.reload).to have_attributes(deleted_by_id: ana.id, restored_by_id: bia.id)
  end

  describe "#restaurar!" do
    it "clears deleted_at, stamps restored_at and logs it" do
      client.excluir!(changed_by: "10.0.0.1")
      client.restaurar!(changed_by: "10.0.0.2")

      expect(client.reload).to have_attributes(excluido?: false, restored_at: be_present)
      expect(client.exclusao_logs.order(:id).pluck(:acao)).to eq(%w[excluido restaurado])
    end
  end

  describe "scopes" do
    it "splits active and trashed without a default_scope" do
      trashed = create(:client, deleted_at: 1.day.ago)
      expect(Client.ativos).to contain_exactly(client)
      expect(Client.excluidos).to contain_exactly(trashed)
      expect(Client.all).to contain_exactly(client, trashed)
    end
  end

  describe ".contagem_ativos" do
    it "counts only active children in a LEFT JOIN + GROUP BY" do
      create(:molde, client: client, nome: "Ativo")
      create(:molde, client: client, nome: "Na lixeira", deleted_at: 1.day.ago)
      row = Client.left_joins(:moldes).select(Client.arel_table[Arel.star], Molde.contagem_ativos(as: "n")).group(:id).find(client.id)
      expect(row.n).to eq(1)
    end
  end

  describe "#aviso_na_lixeira" do
    it "names the record, the date and where to restore it" do
      client.update_columns(deleted_at: Time.zone.local(2026, 9, 20))
      expect(client.aviso_na_lixeira).to eq("Client \"Fagner\" is in the trash (deleted 20/09/2026). Restore it from Lixeira instead of registering it again.")
    end
  end

  describe "#rotulo_lixeira" do
    it "uses each model's own name column" do
      expect(create(:arquivo, filename: "lateral-azul").rotulo_lixeira).to eq("lateral-azul")
      expect(create(:peca, nome: "Língua").rotulo_lixeira).to eq("Língua")
      pedido = create(:pedido)
      expect(pedido.rotulo_lixeira).to eq("Pedido #{pedido.uuid.first(8)}")
    end
  end
end
