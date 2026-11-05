require "rails_helper"
require_relative "../support/producao_calcado"
require_relative "../support/producao_tecido"

# Painel 1/4 (decided 04/11/2026): a pedido's row — a cell per column, its
# block, %, start, deadline and what holds it.
RSpec.describe LinhaDoPainel do
  let(:sem_falta) { instance_double(AguardandoMaterial, do_pedido: []) }

  def linha(pedido, aguardando: sem_falta, **opcoes)
    described_class.call(pedido, aguardando: aguardando, **opcoes)
  end

  def textos(linha)
    linha.celulas.transform_values { |c| [ c.estado, c.texto ] }.reject { |_, (estado, _)| estado == :nao_tem }
  end

  # The Estamparia names the first lock still open (RegistrarBaixaService#estado_da).
  it "shows a confirmed calçado ready to start: Impressão and Corte open, Estamparia waits" do
    l = linha(pedido_calcado_confirmado)
    expect(textos(l)).to eq("arquivos" => [ :feita, "ok" ], "comercial" => [ :feita, "confirmado" ], "material" => [ :feita, "ok" ],
                            "impressao" => [ :pode_comecar, "pode começar" ], "corte" => [ :pode_comecar, "pode começar" ],
                            "estamparia" => [ :travada, "espera Impressão" ], "conferencia" => [ :travada, "espera Estamparia" ],
                            "entrega" => [ :ainda_nao, "—" ])
    expect([ l.bloco, l.percentual, l.trava ]).to eq([ :prontos, 0, "Estamparia: espera Impressão" ])
  end

  it "moves to em andamento with a baixa, and counts its lines in the %" do
    pedido = pedido_calcado_confirmado
    RegistrarBaixaService.call(pedido, etapa: "corte", nivel: "pedido", medida: "0", confirmar: true)
    l = linha(pedido.reload)
    # 2 Corte lines done of 2 + 2 + 2 + 2 lines in all.
    expect([ l.bloco, l.percentual, l.celulas["corte"].estado, l.inicio ]).to eq([ :em_andamento, 25, :feita, pedido.confirmado_em ])
  end

  it "says the deadline passed" do
    pedido = pedido_calcado_confirmado
    pedido.update!(prazo_entrega: Date.new(2026, 11, 3))
    expect(linha(pedido).atrasado?(Date.new(2026, 11, 4))).to be true
    expect(linha(pedido).atrasado?(Date.new(2026, 11, 3))).to be false
  end

  # The spec's molde has no price per pair: a draft of it can't be confirmed (:sem_preco).
  it "keeps a draft in the pendentes: its stages not yet, its pendências in the Comercial" do
    rascunho = create(:pedido, tipo: "calcado")
    expect([ linha(rascunho).bloco, textos(linha(rascunho))["comercial"] ]).to eq([ :pendentes, [ :pendencia, "sem itens" ] ])

    pedido = pedido_calcado_confirmado
    pedido.update_columns(status: "rascunho")
    expect(textos(linha(pedido.reload)).slice("comercial", "impressao")).to eq("comercial" => [ :pendencia, "1 pendência" ], "impressao" => [ :ainda_nao, "—" ])
    expect(linha(pedido).celulas["comercial"].detalhe).to include("preço")
  end

  it "puts a pedido waiting for material in the pendentes, its detail only for the team" do
    pedido = pedido_tecido_confirmado
    falta = AguardandoMaterial::Falta.new(pedido_id: pedido.id, materia_prima: pedido.itens_pedido.first.materia_prima, metros: 12.5)
    aguardando = instance_double(AguardandoMaterial, do_pedido: [ falta ])

    equipe = linha(pedido, aguardando: aguardando)
    expect([ equipe.bloco, equipe.celulas["material"].texto, equipe.celulas["material"].detalhe ]).to eq([ :pendentes, "aguarda material", "#{falta.materia_prima.nome_completo} · faltam 12,5 m" ])
    expect(linha(pedido, aguardando: aguardando, cliente_final: true).celulas["material"].detalhe).to be_nil
  end

  it "shows the tecido's Calandra in the Estamparia column" do
    expect(textos(linha(pedido_tecido_confirmado))["estamparia"]).to eq([ :travada, "espera Impressão" ])
  end

  # Decided 05/11/2026: the reposição inside its original's row; the pair
  # is in every queue, and needs every column, either of them is in.
  it "takes its reposições' queues and columns, their pendências and pieces" do
    pedido = pedido_calcado_confirmado
    reposicao = linha(reposicao_com_falta(pedido))
    original = linha(pedido.reload, reposicoes: [ reposicao ])

    expect(original.com_reposicoes).to eq([ original, reposicao ])
    expect(reposicao.filas).to eq(%w[impressao corte estamparia conferencia])
    expect(original.filas).to eq(%w[entrega impressao corte estamparia conferencia])
    expect(original.fora("entrega" => "Entrega")).to eq(%w[arquivos comercial material impressao corte estamparia conferencia])
    expect([ reposicao.pecas_da_reposicao, original.pecas_da_reposicao ]).to eq([ 2, 0 ])
    pedido.update!(prazo_entrega: Date.new(2026, 11, 20))
    expect(linha(reposicao.pedido.reload).prazo).to eq(Date.new(2026, 11, 20))
    expect(original.pendencia?).to be(false)
    expect(linha(pedido, reposicoes: [ instance_double(described_class, pendencia?: true, pedido: reposicao.pedido) ]).pendencia?).to be(true)
  end

  it "leaves out of the path a stage the reposição doesn't redo" do
    reposicao = linha(reposicao_com_falta(pedido_calcado_confirmado, refazer: "impressao"))
    expect(reposicao.caminho.map { |passo| passo.map(&:chave) }).to eq([ %w[impressao], %w[estamparia], %w[conferencia] ])
  end
end
