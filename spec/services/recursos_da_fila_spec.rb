require "rails_helper"

# Máquinas 2/5a: where a stage's pieces may go — its trabalho's machines,
# else the sector — and the hours a sector has, each resource's summed.
RSpec.describe RecursosDaFila do
  let(:manha) { Turno.new(nome: "Manhã", inicio: "08:00", fim: "12:00", dias: (1..5).to_a) }
  let(:calendario) { CalendarioDeProducao.new(turnos: [ manha ], excecoes: excecoes) }
  let(:excecoes) { [] }
  let(:ocorrencia) { calendario.ocorrencias(de: Time.zone.parse("2026-11-04 07:00"), ate: Time.zone.parse("2026-11-04 13:00")).sole }

  def maquina(nome, **velocidades)
    Maquina.new(nome: nome).tap { |m| velocidades.each { |trabalho, por_hora| m.trabalhos.build(trabalho: trabalho.to_s, por_hora: por_hora) } }.tap(&:save!)
  end

  def recursos
    described_class.new(RitmoProducao.da_fabrica, calendario)
  end

  it "gives a trabalho's machines, the first registered first, with their share; the sector with none" do
    c2 = maquina("Calandra 2", calandra: 40, dublagem: 30)
    c3 = maquina("Calandra 3", calandra: 40)
    lista = recursos.do_ritmo(RitmoProducao.da_fabrica[%w[tecido calandra]], "estamparia")

    expect(lista.map { |r| [ r.chave, r.maquina, r.parte, r.maquina? ] }).to eq([ [ "maquina:#{c2.id}", c2, 0.5, true ], [ "maquina:#{c3.id}", c3, 0.5, true ] ])
    expect(recursos.do_ritmo(RitmoProducao.da_fabrica[%w[calcado estamparia]], "estamparia").map { |r| [ r.chave, r.maquina? ] }).to eq([ [ "estamparia", false ] ])
  end

  it "lists a sector's resources once each, machines first, with the stages they do there, and sums their hours" do
    c2 = maquina("Calandra 2", calandra: 40)
    pares = [ %w[tecido calandra], %w[calcado estamparia] ]

    expect(recursos.do_setor("estamparia", pares).map { |r, etapas| [ r.maquina || r.chave, etapas ] }).to eq([ [ c2, %w[calandra] ], [ "estamparia", %w[estamparia] ] ])
    expect(recursos.horas(ocorrencia, "estamparia", pares)).to eq(8.0)
  end

  context "with the Calandra stopped that day" do
    let(:excecoes) { [ ExcecaoCalendario.new(data: Date.new(2026, 11, 4), nome: "Calandra parada", etapa: "calandra") ] }

    it "takes the stopped stage's machines' hours out" do
      maquina("Calandra 2", calandra: 40)
      expect(recursos.horas(ocorrencia, "estamparia", [ %w[tecido calandra], %w[calcado estamparia] ])).to eq(4.0)
    end
  end
end
