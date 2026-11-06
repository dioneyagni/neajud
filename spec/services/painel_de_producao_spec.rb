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

  # Decided 05/11/2026: a reposição is a row under its original, and the
  # original's Entrega waits for it.
  describe "reposições" do
    let(:pedido) { pedido_calcado_confirmado }

    it "puts a released reposição under its original, whose Entrega waits for it" do
      reposicao = reposicao_com_falta(pedido)
      painel = described_class.call(Pedido.all)
      expect(blocos(painel)[:em_andamento]).to eq([ pedido.id ])
      original = painel.linhas.sole
      expect(original.reposicoes.map { |l| [ l.pedido.id, l.pecas_da_reposicao ] }).to eq([ [ reposicao.id, 2 ] ])
      expect(original.celulas["entrega"].to_h.values_at(:estado, :texto)).to eq([ :travada, "espera reposição" ])
      expect(original.trava).to eq("Entrega: reposição ##{reposicao.uuid.first(8)} ainda em produção")
      # Its 8 lines done, the reposição's 4 open: not 100% while pieces are redone.
      expect([ original.contagem_de_linhas, original.reposicoes.sole.contagem_de_linhas ]).to eq([ [ 8, 8 ], [ 0, 4 ] ])
      expect([ original.percentual, original.percentual_proprio, original.percentual_das_reposicoes ]).to eq([ 66, 100, 0 ])
    end

    it "shows the pieces of a reposição still gathering on its original, not as a row" do
      reposicao_com_falta(pedido, faltam: 3, juntando: true)
      linhas = described_class.call(Pedido.all).linhas
      expect(linhas.map { |l| [ l.pedido.id, l.juntando, l.reposicoes ] }).to eq([ [ pedido.id, 3, [] ] ])
    end

    # The original delivered anyway: the reposição is still to be made.
    it "gives the reposição a row of its own once its original is delivered" do
      reposicao = reposicao_com_falta(pedido)
      pedido.update!(status: "entregue", entregue_em: Time.current)
      expect(described_class.call(Pedido.all).linhas.map { |l| [ l.pedido.id, l.reposicoes ] }).to eq([ [ reposicao.id, [] ] ])
    end

    it "answers a reposição's uuid with its original's row, the reposição inside" do
      reposicao = reposicao_com_falta(pedido)
      linha = described_class.linha(Pedido.all, reposicao.uuid)
      expect([ linha.pedido.id, linha.reposicoes.map { |l| l.pedido.id } ]).to eq([ pedido.id, [ reposicao.id ] ])
    end
  end

  it "gives one pedido's row, nil once it leaves the Painel" do
    pedido = pedido_calcado_confirmado
    expect(described_class.linha(Pedido.all, pedido.uuid).bloco).to eq(:prontos)
    pedido.excluir!(changed_by: "spec")
    expect(described_class.linha(Pedido.all, pedido.uuid)).to be_nil
  end
end
