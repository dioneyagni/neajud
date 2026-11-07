require "rails_helper"
require_relative "../support/producao_calcado"
require_relative "../support/fila_de_producao"

# Painel 1/4: the rows, only what the person sees; empty columns hidden.
# Painel 2/4b: in blocks in time (BlocosNoTempo), each with its previsão
# from the whole factory's queue (FilaDeProducao).
RSpec.describe PainelDeProducao do
  def blocos(painel)
    painel.blocos.to_h { |b| [ b.chave, b.linhas.map { |l| l.pedido.id } ] }
  end

  it "puts a row where its next piece of work is: now once there are turnos and rhythms, else without previsão" do
    rascunho = create(:pedido)
    pedido = pedido_calcado_confirmado
    expect(blocos(described_class.call(Pedido.all))).to eq("agora" => [], "sem_previsao" => [ pedido.id ], "pendentes" => [ rascunho.id ])

    turno_o_dia_todo
    ritmos_do_calcado
    painel = described_class.call(Pedido.all)
    expect(blocos(painel)).to eq("agora" => [ pedido.id ], "sem_previsao" => [], "pendentes" => [ rascunho.id ])
    expect(painel.linhas.first.previsao.fim).to be > Time.current
    expect(painel.fila.do_setor("impressao").map(&:pedido)).to eq([ pedido ])
  end

  # A cliente final's previsão moves with every client's pedidos (Q4a).
  it "computes the queue with the whole factory, showing only the scope's rows" do
    turno_o_dia_todo
    ritmos_do_calcado
    outro = pedido_calcado_confirmado
    meu = pedido_calcado_confirmado
    painel = described_class.call(Pedido.where(client: meu.client), cliente_final: true)
    expect(painel.linhas.map(&:pedido)).to eq([ meu ])
    expect(painel.fila.do_setor("impressao").map(&:pedido)).to eq([ outro, meu ])
  end

  it "leaves out the trashed, the delivered (unless asked, 7 days) and a reposição still gathering" do
    pedido = pedido_calcado_confirmado
    create(:pedido).excluir!(changed_by: "spec")
    create(:pedido, status: "rascunho", reposicao_de: pedido)
    entregue = create(:pedido, status: "entregue", entregue_em: 2.days.ago)
    create(:pedido, status: "entregue", entregue_em: 8.days.ago)

    expect(described_class.call(Pedido.all).linhas.map { |l| l.pedido.id }).to eq([ pedido.id ])
    expect(blocos(described_class.call(Pedido.all, entregues: true))["entregues"]).to eq([ entregue.id ])
  end

  # Painel 2/4c: the Linha do tempo's record, apart from the blocks; their
  # stages are not read (only when it started and was delivered).
  it "brings the pedidos delivered inside the Linha do tempo's window, of the scope given" do
    meu = create(:pedido, status: "entregue", entregue_em: Time.zone.parse("2026-10-20 15:00"))
    create(:pedido, status: "entregue", entregue_em: Time.zone.parse("2026-10-20 15:00"))
    create(:pedido, status: "entregue", entregue_em: Time.zone.parse("2026-11-03 00:00"))
    janela = Date.new(2026, 10, 20)..Date.new(2026, 11, 2)

    painel = described_class.call(Pedido.where(id: [ meu.id ] + Pedido.where(entregue_em: Time.zone.parse("2026-11-03 00:00")).ids), janela: janela)
    expect(painel.entregues_na_janela.map { |l| [ l.pedido.id, l.estados ] }).to eq([ [ meu.id, {} ] ])
    expect(described_class.call(Pedido.all).entregues_na_janela).to eq([])
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
      # Without turnos the reposição has no previsão, and the pair with it.
      expect(blocos(painel)["sem_previsao"]).to eq([ pedido.id ])
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
  end
end
