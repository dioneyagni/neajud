require "rails_helper"
require_relative "../support/construcoes"

# Dublagem 5b1c2 (decided 11/11/2026, canvas "5b1c2 · Dublagem no Painel e
# na fila"): two columns (Q1a) — Dublagem by the Impressão, Dublagem final
# after the Estamparia —, one sector and queue for both (Q2a), where the
# Dublagem final never holds the ones behind it while its Calandra is not
# done (Q3b), and the queue names each letra with its pedido (Q4). The
# chave: DUB-A, B and C in the Dublagem, DUB-D in the Dublagem final.
RSpec.describe "Dublagem no Painel e na fila" do
  include ActiveSupport::Testing::TimeHelpers

  let(:sem_falta) { instance_double(AguardandoMaterial, do_pedido: []) }
  # Wednesday.
  let(:quarta) { Time.zone.parse("2026-11-04 08:00") }
  let(:construcao) { construcao_dublada_no_pedido }

  before do
    Turno.create!(nome: "Manhã", inicio: "08:00", fim: "12:00", dias: (1..5).to_a)
    Turno.create!(nome: "Tarde", inicio: "13:00", fim: "17:00", dias: (1..5).to_a)
    # 10 m each: 1 h a stage, the Dublagem's three letras 30 m.
    { "impressao" => 10, "calandra" => 10, "dublagem" => 30, "dublagem_final" => 10 }.each do |etapa, por_hora|
      RitmoProducao.create!(tipo: "tecido", etapa: etapa, por_hora: por_hora)
    end
  end

  def dublado(confirmado_em)
    pedido_dublado_confirmado(construcao, metros: 10).tap { |pedido| pedido.update_columns(confirmado_em: confirmado_em) }
  end

  def fila = FilaDeProducao.call(agora: quarta, aguardando: sem_falta)

  def horario(vez) = vez.trechos.map { |trecho| "#{trecho.inicio.strftime("%H:%M")}–#{trecho.fim.strftime("%H:%M")}" }.join(" ")

  it "gives the Dublagem its two columns and one sector, its tab and its line in the Linha do tempo" do
    pedido = dublado(quarta - 1.hour)
    painel = PainelDeProducao.call(Pedido.where(id: pedido.id))
    linha = painel.linhas.sole

    expect(painel.colunas.keys).to eq(%w[arquivos comercial material impressao dublagem estamparia dublagem_final entrega])
    expect([ linha.celulas["dublagem"].texto, linha.celulas["dublagem_final"].texto ]).to eq([ "pode começar", "espera Calandra" ])
    # The Dublagem final is in the Dublagem's queue: never a queue of its own.
    expect(linha.filas).to include("dublagem")
    expect(linha.filas).not_to include("dublagem_final")
    expect(LinhaDoPainel.setores_usados(painel.colunas, %w[impressao corte estamparia dublagem conferencia entrega]).keys).to eq(%w[impressao estamparia dublagem entrega])
    expect(FilaDeProducao.setor_de(EtapasProducao.etapa("tecido", "dublagem_final", pedido: pedido))).to eq("dublagem")
    tempo = LinhaDoTempo.call(painel.linhas, fila: painel.fila, de: quarta.to_date, setores: LinhaDoPainel.setores_usados(painel.colunas, LinhaDoTempo::SETORES).keys)
    expect(tempo.cargas.map(&:setor)).to eq(%w[impressao estamparia dublagem])
  end

  # Q3b: by arrival, the first pedido's Dublagem final came before the
  # second's Dublagem; it waits for its Calandra (until 10:00), so the
  # second's Dublagem runs at 09:00 instead of the machine standing still.
  it "lets the Dublagem final wait for its Calandra without holding the ones behind it" do
    primeiro = dublado(quarta - 2.hours)
    segundo = dublado(quarta - 1.hour)
    f = fila

    expect(f.do_setor("dublagem").map { |vez| [ vez.pedido == primeiro ? "1º" : "2º", vez.etapa.chave, vez.posicao, horario(vez) ] }).to eq([
      [ "1º", "dublagem", 1, "08:00–09:00" ], [ "2º", "dublagem", 2, "09:00–10:00" ],
      [ "1º", "dublagem_final", 3, "10:00–11:00" ], [ "2º", "dublagem_final", 4, "11:00–12:00" ]
    ])
    expect(f.do_setor("dublagem").third.espera.etapa.chave).to eq("calandra")
  end

  it "keeps the arrival order where nothing waits for another sector" do
    primeiro = dublado(quarta - 2.hours)
    segundo = dublado(quarta - 1.hour)

    expect(fila.do_setor("impressao").map(&:pedido)).to eq([ primeiro, segundo ])
  end

  # Q2a: one machine — a Dublagem stop stops the Dublagem final too; the
  # list offers it once.
  it "stops both stages with one Dublagem stop, offered once" do
    pedido = dublado(quarta - 1.hour)
    ExcecaoCalendario.create!(data: quarta.to_date, nome: "Dublagem parada", etapa: "dublagem")

    expect(fila.do_setor("dublagem").map { |vez| vez.trechos.first.inicio.to_date }.uniq).to eq([ quarta.to_date + 1 ])
    expect(fila.previsao(pedido).vezes.find { |vez| vez.etapa.chave == "impressao" }.trechos.first.inicio).to eq(quarta)
    expect(ExcecaoCalendario.etapas).to include("dublagem" => "Dublagem (as duas etapas)", "calandra" => "Calandra")
    expect(ExcecaoCalendario.etapas).not_to have_key("dublagem_final")
  end
end
