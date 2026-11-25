require "rails_helper"

# Máquinas 4/5b (decided 24/11/2026, canvas "Máquinas", 10–12): the Máquinas
# list and a machine's page say what each machine measured and uses; the fix
# ("usar a informada") is each machine's, written to its histórico; Ritmos
# sums a stage's machines. The baixas are given at 10:00 of 8 h turnos.
RSpec.describe "Medido por máquina", type: :request do
  def html = Nokogiri::HTML(response.body)

  before { Turno.create!(nome: "Manhã", inicio: "06:00", fim: "14:00", dias: (0..6).to_a) }

  def maquina(nome, **velocidades)
    Maquina.new(nome: nome).tap { |m| velocidades.each { |trabalho, por_hora| m.trabalhos.build(trabalho: trabalho.to_s, por_hora: por_hora) } }.tap(&:save!)
  end

  # Five turnos on the machine, the last days: metros per 8 h turno.
  def baixas(em, metros, pedido: create(:pedido, tipo: "tecido"), etapa: "calandra")
    5.times do |dia|
      BaixaProducao.new(uuid: SecureRandom.uuid, pedido: pedido, etapa: etapa, nivel: "pedido", linhas: [ "x" ], medida: metros, maquina: em,
                        created_at: (dia + 1).days.ago.change(hour: 10)).tap { |b| b.save!(validate: false) }
    end
  end

  def texto(seletor) = html.at_css(seletor).text.squish

  let!(:calandra_2) { maquina("Calandra 2", calandra: 40) }
  let!(:calandra_3) { maquina("Calandra 3", calandra: 40) }

  it "lists each machine's measure and what it uses, the turnos missing, and a fixed one" do
    baixas(calandra_2, 288)
    calandra_3.trabalho_de("calandra").update!(fixar_informado: true)
    get parametros_maquinas_path
    linhas = html.css(".maquinas-lista tbody tr").map { |tr| tr.css("td").map { |td| td.text.squish }.first(5) }
    expect(linhas).to eq([ [ "Calandra 2", "Calandra", "40 m/h", "36 m/h · 5 turnos", "medida · 36 m/h" ],
                           [ "Calandra 3", "Calandra", "40 m/h", "faltam 5 turnos", "informada · 40 m/h fixada" ] ])
  end

  it "fixes a trabalho at its informada on the machine's page, the histórico saying it, and lets it go" do
    baixas(calandra_2, 288)
    get edit_parametros_maquina_path(calandra_2)
    expect(texto("[data-uso-de='calandra'] [data-medida]")).to eq("medida 36 m/h · 5 turnos · em uso: medida · 36 m/h")

    fixar = ->(valor) { patch parametros_maquina_path(calandra_2), params: { maquina: { nome: "Calandra 2", trabalhos: { calandra: { marcado: "1", por_hora: "40", fixar_informado: valor } } } } }
    fixar.call("1")
    expect([ calandra_2.trabalho_de("calandra").reload.fixar_informado, calandra_2.alteracoes.recentes.first.texto ]).to eq([ true, "Calandra: passou a usar a informada" ])
    get edit_parametros_maquina_path(calandra_2)
    expect([ html.at_css("#fixar_calandra").key?("checked"), texto("[data-uso-de='calandra'] [data-medida]") ]).to eq([ true, "medida 36 m/h · 5 turnos · em uso: informada · 40 m/h" ])

    fixar.call("0")
    expect(calandra_2.alteracoes.recentes.first.texto).to eq("Calandra: voltou a usar a medida")
  end

  it "keeps the fix when the page doesn't send it (a trabalho just checked)" do
    calandra_2.trabalho_de("calandra").update!(fixar_informado: true)
    patch parametros_maquina_path(calandra_2), params: { maquina: { nome: "Calandra 2", trabalhos: { calandra: { marcado: "1", por_hora: "50" } } } }
    expect([ calandra_2.reload.trabalho_de("calandra").fixar_informado, calandra_2.alteracoes.recentes.first.texto ]).to eq([ true, "Calandra 40 m/h → 50 m/h" ])
  end

  it "sums a stage's machines in Ritmos: their measures, the fixed ones and what they use" do
    baixas(calandra_2, 288)
    get edit_parametros_ritmos_path
    expect([ texto("tr[data-ritmo='tecido:calandra'] [data-medido-das-maquinas]"), texto("tr[data-ritmo='tecido:calandra'] [data-fix-das-maquinas]"),
             texto("tr[data-ritmo='tecido:calandra'] [data-em-uso-das-maquinas]") ])
      .to eq([ "36 m/h · 1 de 2 máquinas", "nas máquinas", "54 m/h · 36 medida + 18 da etapa" ])

    calandra_2.trabalho_de("calandra").update!(fixar_informado: true)
    get edit_parametros_ritmos_path
    expect([ texto("tr[data-ritmo='tecido:calandra'] [data-fix-das-maquinas]"), texto("tr[data-ritmo='tecido:calandra'] [data-em-uso-das-maquinas]") ])
      .to eq([ "fixado em 1 de 2 máquinas", "58 m/h · 40 informada + 18 da etapa" ])
  end
end
