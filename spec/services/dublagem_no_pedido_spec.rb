require "rails_helper"
require_relative "../support/construcoes"

# Dublagem 5b1c1 (decided 11/11/2026): an item whose construção dubs after
# the Calandra is dubbed in the pedido. The canvas's chave with this
# network's groups — DUB-A Oxford/Oxford and DUB-B Espuma/Helanca in the 1st
# dublagem, DUB-C = DUB-B with Espuma in the 2nd, DUB-D = DUB-A with DUB-C in
# the 3rd (Oxford–Espuma dubs after the estampa): DUB-A, B and C in the
# Dublagem, DUB-D in the Dublagem final.
RSpec.describe "Dublagem no pedido" do
  let(:cliente) { create(:client) }
  let(:oxford) { construcao.superficie.materia_prima }
  let(:filme) { construcao.camadas_em_ordem.second.ligante }
  let(:construcao) { construcao_dublada_no_pedido }
  let(:pedido) { pedido_dublado_confirmado(construcao, metros: 10, client: cliente) }
  let(:item) { pedido.itens_pedido.sole }

  def chave(letra) = LinhasDeProducao.chave_da_dublagem(item, item.letras_da_dublagem.find { |dublagem| dublagem.letra == letra })

  def linhas(etapa) = LinhasDeProducao.call(pedido, EtapasProducao.etapa("tecido", etapa, pedido: pedido))

  def baixa(etapa, nivel: "pedido", alvo: nil) = RegistrarBaixaService.call(pedido, etapa: etapa, nivel: nivel, alvo: alvo, medida: "10", confirmar: true)

  def estados(etapa) = RegistrarBaixaService.situacao(pedido, etapa).transform_values(&:estado)

  it "gives the pedido its Dublagem stages, the letras before the Calandra in one and after it in the other" do
    expect(EtapasProducao.do_tipo("tecido", pedido: pedido).map(&:chave)).to eq(%w[impressao dublagem calandra dublagem_final])
    expect(linhas("dublagem").map { |linha| [ linha.dublagem.letra, linha.esperado, linha.espera.map(&:nome) ] })
      .to eq([ [ "DUB-A", 10.0, [] ], [ "DUB-B", 10.0, [] ], [ "DUB-C", 10.0, [ "DUB-B" ] ] ])
    expect(linhas("dublagem_final").map { |linha| [ linha.dublagem.letra, linha.espera.map(&:nome) ] }).to eq([ [ "DUB-D", %w[Calandra DUB-C] ] ])
    expect(linhas("calandra").sole.espera.map(&:nome)).to eq(%w[Impressão DUB-A])
  end

  it "leaves a pedido without an item dubbed in it as it was" do
    so_antes = montar_construcao([ oxford, "trama" ], [ oxford, filme ]).tap(&:save!)
    outro = pedido_dublado_confirmado(so_antes, metros: 5, client: cliente)

    expect(EtapasProducao.do_tipo("tecido", pedido: outro).map(&:chave)).to eq(%w[impressao calandra])
    expect(LinhasDeProducao.call(outro, EtapasProducao.etapa("tecido", "calandra")).sole.espera.map(&:nome)).to eq([ "Impressão" ])
  end

  # 5b Q8a: 1 m a meter of each layer from its owner, and of each ligante.
  it "takes each layer and ligante from the stock at confirmation, never the superfície alone" do
    saidas = pedido.movimentos_estoque.where(tipo: "saida").map { |movimento| [ movimento.materia_prima.grupo_material.nome, movimento.quantidade.to_f ] }

    expect(saidas).to contain_exactly([ "Oxford", 20.0 ], [ "Espuma", 20.0 ], [ "Helanca", 10.0 ], [ "Filme", 10.0 ])
  end

  it "takes a letra's baixa only once what it waits for is done, the pedido's covering the free ones" do
    baixa("dublagem")
    expect(estados("dublagem")).to eq(chave("DUB-A") => :feita, chave("DUB-B") => :feita, chave("DUB-C") => :aberta)
    expect(estados("calandra").values).to eq([ :aguardando ])

    erro = RegistrarBaixaService.call(pedido, etapa: "dublagem_final", nivel: "linha", alvo: chave("DUB-D"), medida: "10", confirmar: true)
    expect(erro.mensagem).to start_with("Waiting for Calandra")
    baixa("dublagem")
    baixa("impressao")
    baixa("calandra")
    expect(estados("dublagem_final").values).to eq([ :aberta ])
  end

  # A baixa another line waited for is undone after that one's.
  it "refuses to undo a letra's baixa while the letra joining it has one" do
    baixa("dublagem")
    baixa("dublagem")
    da_b = pedido.baixas_producao.vigentes.da_etapa("dublagem").order(:created_at).first

    expect(DesfazerBaixaService.call(da_b, user: create(:user))).to eq("Undo Dublagem's baixa of these lines first: it waited for this one.")
  end

  # Their columns and queue are 5b1c2's: until then the Painel and the
  # queue go on, the Calandra's cell naming what it waits for.
  it "keeps the Painel and the queue working, the Calandra's cell naming what it waits for" do
    painel = -> { PainelDeProducao.call(Pedido.where(id: pedido.id)) }
    expect(painel.().linhas.sole.celulas["estamparia"].texto).to eq("espera Impressão")

    baixa("impressao")
    linha = painel.().linhas.sole
    expect(linha.celulas["estamparia"].texto).to eq("espera DUB-A")
    expect(linha.caminho.flatten.map(&:chave)).to include("dublagem", "dublagem_final")
    expect(painel.().colunas.keys).not_to include("dublagem")
  end
end
