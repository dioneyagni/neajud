require "rails_helper"
require_relative "../support/construcoes"

# Dublagem 5b2b (decided 12/11/2026): the cola, counted in kg (5b2a), takes
# its consumption over the construção's width per meter dubbed (Q2a), costs
# its price per kg times that in the suggested price — the card keeps one
# line (Q3a) — and, short in the stock, goes out all the same and only warns
# (Q4b). The chave: DUB-A Espuma/Helanca on cola in the Dublagem, DUB-B
# Oxford over DUB-A on cola in the Dublagem final; 1,40 m wide, the cola
# 120 g/m² → 0,168 kg a meter.
RSpec.describe "Cola na dublagem" do
  let(:cola) do
    grupo_de_dublagem("Cola").update!(unidade: "kg")
    MateriaPrima.create!(grupo_material: grupo_de_dublagem("Cola"), cor_material: CorMaterial.find_or_create_by!(nome: "Branco"), tipo: "filme",
                         consumo_g_m2: 120, preco_metro: 18)
  end
  let(:construcao) do
    construcao = Construcao.new(preco_final: 90)
    construcao.definir_camadas([ { materia_prima: material_de_dublagem("Oxford", preco: 20), lado: "trama" },
                                 { materia_prima: material_de_dublagem("Espuma", densidade: "TC4", preco: 10), ligante: cola, ordem_da_dublagem: 2 },
                                 { materia_prima: material_de_dublagem("Helanca", preco: 5), ligante: cola, ordem_da_dublagem: 1 } ])
    construcao.tap(&:save!)
  end

  def linhas(pedido, etapa) = LinhasDeProducao.call(pedido, EtapasProducao.etapa("tecido", etapa, pedido: pedido))

  def linha(pedido, letra) = (linhas(pedido, "dublagem") + linhas(pedido, "dublagem_final")).find { |l| l.dublagem.letra == letra }

  # Everything in but the cola: the pedido takes 3,36 kg it doesn't have.
  def pedido_sem_cola
    ComponentesDaDublagem.new(construcao).reject { |componente| componente.materia_prima == cola }.each do |componente|
      MovimentoEstoque.create!(materia_prima: componente.materia_prima, da_empresa: true, tipo: "entrada", quantidade: 10 * componente.por_metro)
    end
    pedido_dublado_confirmado(construcao, metros: 10, estoque: false)
  end

  it "takes the consumption over the width, per ligação, from the stock" do
    expect(cola.por_metro_dublado(1400)).to eq(0.168)
    expect([ construcao.largura_mais_estreita_mm, ComponentesDaDublagem.new(construcao).find { |c| c.materia_prima == cola }.por_metro ]).to eq([ 1400, 0.336 ])

    pedido = pedido_dublado_confirmado(construcao, metros: 10)
    expect(pedido.movimentos_estoque.where(materia_prima: cola).sum(:quantidade)).to eq(3.36)
    expect(MateriaisDaLetra.call(linha(pedido, "DUB-A")).map { |parte| [ parte.materia_prima.grupo_material.nome, parte.esperado ] })
      .to eq([ [ "Espuma", 10.0 ], [ "Helanca", 10.0 ], [ "Cola", 1.68 ] ])
  end

  it "prices the cola per kg in the card's one line, and says when it has no consumption" do
    preco = PrecoSugeridoDaConstrucao.new(construcao, servico: 2)
    dub_a = ChaveDaConstrucao.new(construcao).dublagens.find { |d| d.letra == "DUB-A" }
    expect(preco.linhas_da_dublagem(dub_a).map { |l| [ l.rotulo, l.valor ] }.last(2)).to eq([ [ cola.nome_da_camada, 3.02 ], [ "serviço", 2 ] ])

    cola.update_columns(consumo_g_m2: nil)
    linha_da_cola = PrecoSugeridoDaConstrucao.new(construcao.reload, servico: 2).linhas_da_dublagem(dub_a).find { |l| l.rotulo == cola.nome_da_camada }
    expect([ linha_da_cola.valor, linha_da_cola.nota ]).to eq([ nil, "sem consumo" ])
  end

  # Q4b: the cola short holds nothing — no wait, no held letra, no entry.
  it "lets the cola go below zero, warning only" do
    pedido = pedido_sem_cola
    aguardando = AguardandoMaterial.call

    expect([ aguardando.do_pedido(pedido), aguardando.pedido_ids ]).to eq([ [], [] ])
    expect(aguardando.avisos_do_pedido(pedido).map { |falta| [ falta.materia_prima, falta.metros ] }).to eq([ [ cola, 3.36 ] ])
    expect(MateriaisDaLetra.presas(linhas(pedido, "dublagem") + linhas(pedido, "dublagem_final"), aguardando.do_pedido(pedido))).to eq({})
    baixa = RegistrarBaixaService.call(pedido, etapa: "dublagem", nivel: "linha", alvo: linha(pedido, "DUB-A").chave, medida: "10", confirmar: true, user: create(:vinculo).user)
    expect(baixa.estado).to eq(:ok)
    expect(MovimentoEstoque.entradas.where(materia_prima: cola)).to be_empty
  end

  it "keeps the Painel's cells, the warning in the Dublagem's detail" do
    pedido = pedido_sem_cola
    linha_do_painel = LinhaDoPainel.call(pedido, aguardando: AguardandoMaterial.call)

    expect(linha_do_painel.celulas["material"].texto).to eq("ok")
    expect(linha_do_painel.celulas["dublagem"].texto).to eq("pode começar")
    expect(linha_do_painel.celulas["dublagem"].detalhe).to end_with("#{cola.nome_completo} · faltam 3,36 kg · não trava")
    # The cliente final never reads the empresa's cola.
    expect(LinhaDoPainel.call(pedido, aguardando: AguardandoMaterial.call, cliente_final: true).celulas["dublagem"].detalhe.to_s).not_to include("Cola")
  end
end
