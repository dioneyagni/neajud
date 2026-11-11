require "rails_helper"
require_relative "../support/construcoes"

# Dublagem 5b1c3 (decided 11/11/2026, canvas Painel "5b1c2 · Dublagem no
# Painel e na fila", section 5): a missing material holds only the letras
# that take it — a layer of their own or their ligante — and the ones
# waiting for them (Q1a); a held letra's baixa asks for the entry (Q2a); the
# stage goes in the queue with the free letras (Q3a). The chave: DUB-A
# Oxford/Oxford with filme, DUB-B Espuma/Helanca, DUB-C = DUB-B with Espuma,
# DUB-D = DUB-A with DUB-C (the Dublagem final). The Espuma is missing.
RSpec.describe "Falta de material da letra" do
  include ActiveSupport::Testing::TimeHelpers

  let(:construcao) { construcao_dublada_no_pedido }
  let(:espuma) { construcao.camadas_em_ordem.third.materia_prima }
  let(:estoquista) { create(:vinculo).user }
  let(:quarta) { Time.zone.parse("2026-11-04 08:00") }
  let(:pedido) do
    ComponentesDaDublagem.new(construcao).reject { |componente| componente.materia_prima == espuma }.each do |componente|
      MovimentoEstoque.create!(materia_prima: componente.materia_prima, client: componente.client, da_empresa: componente.client.nil?, tipo: "entrada", quantidade: 10 * componente.por_metro)
    end
    pedido_dublado_confirmado(construcao, metros: 10, estoque: false)
  end

  def linhas(etapa) = LinhasDeProducao.call(pedido, EtapasProducao.etapa("tecido", etapa, pedido: pedido))

  def linha(letra) = (linhas("dublagem") + linhas("dublagem_final")).find { |l| l.dublagem.letra == letra }

  def baixa(letra, **dados)
    etapa = linhas("dublagem").any? { |l| l.dublagem.letra == letra } ? "dublagem" : "dublagem_final"
    RegistrarBaixaService.call(pedido, etapa: etapa, nivel: "linha", alvo: linha(letra).chave, medida: "10", confirmar: true, user: estoquista, **dados)
  end

  it "says what each letra takes itself: its layers and ligante, never an earlier letra's" do
    nomes = ->(letra) { MateriaisDaLetra.call(linha(letra)).map { |parte| [ parte.materia_prima.grupo_material.nome, parte.esperado ] } }

    expect(%w[DUB-A DUB-B DUB-C DUB-D].map { |letra| nomes.(letra) })
      .to eq([ [ [ "Oxford", 10.0 ], [ "Filme", 10.0 ] ], [ [ "Espuma", 10.0 ], [ "Helanca", 10.0 ] ], [ [ "Espuma", 10.0 ] ], [] ])
  end

  it "holds the letras taking the missing material and the ones waiting for them" do
    presas = MateriaisDaLetra.presas(linhas("dublagem") + linhas("dublagem_final"), AguardandoMaterial.call.do_pedido(pedido))

    expect(presas.transform_keys { |chave| (linhas("dublagem") + linhas("dublagem_final")).find { |l| l.chave == chave }.dublagem.letra })
      .to eq("DUB-B" => [ espuma ], "DUB-C" => [ espuma ], "DUB-D" => [ espuma ])
  end

  it "asks a held letra's baixa for the entry, never the free one's, and takes it with the entry" do
    expect(baixa("DUB-A").estado).to eq(:ok)

    pedida = baixa("DUB-B")
    expect([ pedida.estado, pedida.faltas.map { |falta| [ falta.materia_prima, falta.falta ] } ]).to eq([ :falta_material, [ [ espuma, 20.0 ] ] ])
    expect(pedido.baixas_producao.vigentes.da_etapa("dublagem").count).to eq(1)

    chave = "#{espuma.uuid}:empresa"
    expect(baixa("DUB-B", entradas: { chave => "20" }).estado).to eq(:ok)
    expect(MovimentoEstoque.entradas.where(materia_prima: espuma).sum(:quantidade).to_f).to eq(20.0)
  end

  # Q3a: the Impressão and the Calandra run; the Dublagem with DUB-A only.
  it "puts the stage in the queue with the free letras, the pedido without previsão until the material comes" do
    Turno.create!(nome: "Manhã", inicio: "08:00", fim: "12:00", dias: (1..5).to_a)
    { "impressao" => 10, "calandra" => 10, "dublagem" => 10, "dublagem_final" => 10 }.each { |etapa, por_hora| RitmoProducao.create!(tipo: "tecido", etapa: etapa, por_hora: por_hora) }
    pedido
    fila = FilaDeProducao.call(agora: quarta)
    vezes = fila.previsao(pedido).vezes.index_by { |vez| vez.etapa.chave }

    expect(vezes["impressao"].fim).to be_present
    expect(vezes["calandra"].fim).to be_present
    expect([ vezes["dublagem"].linhas.map { |l| l.dublagem.letra }, vezes["dublagem"].retidas.map { |l| l.dublagem.letra }, vezes["dublagem"].horas ])
      .to eq([ [ "DUB-A" ], %w[DUB-B DUB-C], 1.0 ])
    expect([ vezes["dublagem_final"].fim, vezes["dublagem_final"].motivo ]).to eq([ nil, "previsão quando #{espuma.nome_completo} entrar" ])
    expect([ fila.previsao(pedido).fim, fila.previsao(pedido).sem_previsao ]).to eq([ nil, "previsão quando #{espuma.nome_completo} entrar" ])
  end
end
