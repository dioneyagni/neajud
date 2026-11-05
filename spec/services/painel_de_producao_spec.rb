require "rails_helper"
require_relative "../support/producao_calcado"

# Painel 1/4: the rows by block, the most urgent first, only what the
# person sees; empty columns hidden.
RSpec.describe PainelDeProducao do
  def blocos(painel)
    painel.blocos.to_h { |b| [ b.chave, b.linhas.map { |l| l.pedido.id } ] }
  end

  it "groups by status and orders by late, pendência, deadline, arrival" do
    hoje = Date.new(2026, 11, 4)
    sem_prazo = pedido_calcado_confirmado
    mais_tarde = pedido_calcado_confirmado.tap { |p| p.update!(prazo_entrega: hoje + 9) }
    logo = pedido_calcado_confirmado.tap { |p| p.update!(prazo_entrega: hoje + 1) }
    atrasado = pedido_calcado_confirmado.tap { |p| p.update!(prazo_entrega: hoje - 1) }
    rascunho = create(:pedido)

    painel = described_class.call(Pedido.all, hoje: hoje)
    expect(blocos(painel)).to eq(em_andamento: [], prontos: [ atrasado.id, logo.id, mais_tarde.id, sem_prazo.id ], pendentes: [ rascunho.id ])
  end

  it "leaves out the trashed, the delivered (unless asked, 7 days) and a reposição still gathering" do
    pedido = pedido_calcado_confirmado
    create(:pedido).excluir!(changed_by: "spec")
    create(:pedido, status: "rascunho", reposicao_de: pedido)
    entregue = create(:pedido, status: "entregue", entregue_em: 2.days.ago)
    create(:pedido, status: "entregue", entregue_em: 8.days.ago)

    expect(described_class.call(Pedido.all).linhas.map { |l| l.pedido.id }).to eq([ pedido.id ])
    expect(blocos(described_class.call(Pedido.all, entregues: true))[:entregues]).to eq([ entregue.id ])
  end

  it "shows only the pedidos of the scope given (visiveis)" do
    meu = pedido_calcado_confirmado
    pedido_calcado_confirmado
    expect(described_class.call(Pedido.where(client: meu.client)).linhas.map { |l| l.pedido.id }).to eq([ meu.id ])
  end

  it "hides the columns no row goes through" do
    create(:pedido)
    expect(described_class.call(Pedido.all).colunas.keys).to eq(%w[comercial material entrega])
  end

  it "gives one pedido's row, nil once it leaves the Painel" do
    pedido = pedido_calcado_confirmado
    expect(described_class.linha(Pedido.all, pedido.uuid).bloco).to eq(:prontos)
    pedido.excluir!(changed_by: "spec")
    expect(described_class.linha(Pedido.all, pedido.uuid)).to be_nil
  end
end
