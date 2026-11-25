require "rails_helper"
require_relative "../support/producao_tecido"

# Máquinas 3/5a (decided 24/11/2026): a stop of machines takes each whole
# (Q1a); the loose pieces go by themselves to the others, the ones held or
# started on it wait for it (Q2a); "voltou a funcionar" gives it back from
# then on (Q7a); saving keeps what it did to the queue (Q3a, Q4a). A tecido
# pedido prints 15,5 m (08:00–09:00 on Wednesday) and runs 12,5 + 3 m on
# the Calandra: 1 h on the Calandra 2 (15,5 m/h), 30 min on the Calandra 3.
RSpec.describe "Parada por máquina" do
  let(:sem_falta) { instance_double(AguardandoMaterial, avisos_do_pedido: [], do_pedido: []) }
  # Wednesday.
  let(:quarta) { Time.zone.parse("2026-11-04 08:00") }
  let(:pessoa) { create(:user) }
  let!(:lenta) { maquina("Calandra 2", calandra: 15.5, dublagem: 30) }
  let!(:rapida) { maquina("Calandra 3", calandra: 31) }
  let!(:pedido) { pedido_tecido_confirmado.tap { |p| p.update_columns(confirmado_em: quarta - 1.hour) } }

  before do
    Turno.create!(nome: "Manhã", inicio: "08:00", fim: "12:00", dias: (1..5).to_a)
    Turno.create!(nome: "Tarde", inicio: "13:00", fim: "17:00", dias: (1..5).to_a)
    RitmoProducao.create!(tipo: "tecido", etapa: "impressao", por_hora: 15.5)
  end

  def maquina(nome, **velocidades)
    Maquina.new(nome: nome).tap { |m| velocidades.each { |trabalho, por_hora| m.trabalhos.build(trabalho: trabalho.to_s, por_hora: por_hora) } }.tap(&:save!)
  end

  def parar(*maquinas, dias: 1, **atributos)
    ExcecaoCalendario.new(nome: "Manutenção", data: quarta.to_date, data_fim: quarta.to_date + dias - 1, etapa: "calandra", **atributos).tap do |parada|
      maquinas.each { |m| parada.paradas_das_maquinas.build(maquina: m) }
      parada.save!
    end
  end

  def fila
    FilaDeProducao.call(agora: quarta, aguardando: sem_falta)
  end

  def calandra(na = fila)
    na.previsao(pedido).vezes.find { |v| v.etapa.chave == "calandra" }
  end

  def prender(em)
    MovimentoDaFila.create!(pedido: pedido, user: pessoa, etapa: "calandra", setor: "estamparia", de_maquina: (rapida if em == lenta), para_maquina: em)
  end

  describe FilaDeProducao do
    it "sends a loose piece to another machine while its own stops, and the sector counts the others' hours only" do
      expect(calandra.maquina).to eq(rapida)
      parar(rapida)
      vez = calandra
      expect([ vez.maquina, vez.inicio.strftime("%a %H:%M"), vez.fim.strftime("%H:%M") ]).to eq([ lenta, "Wed 09:00", "10:00" ])
      manha = fila.ocorrencias.first
      expect(fila.horas_do_setor(manha, "estamparia", desde: quarta)).to eq(4.0)
    end

    it "keeps a held piece on its stopped machine, waiting for it (Q2a)" do
      prender(rapida)
      parar(rapida, dias: 2)
      expect([ calandra.maquina, calandra.inicio.strftime("%a %H:%M") ]).to eq([ rapida, "Fri 08:00" ])
    end

    it "keeps a started piece on the machine of its baixa, waiting for it (Q2a)" do
      RegistrarBaixaService.call(pedido, etapa: "impressao", nivel: "pedido", medida: "15,5", confirmar: true)
      alvo = EstadoDasEtapas.call(pedido)["calandra"].keys.first
      RegistrarBaixaService.call(pedido, etapa: "calandra", nivel: "linha", alvo: alvo, medida: "12,5", confirmar: true, maquina: rapida.uuid, user: pessoa)
      parar(rapida)
      expect([ calandra.maquina, calandra.inicio.strftime("%a %H:%M") ]).to eq([ rapida, "Thu 08:00" ])
    end

    it "stops a machine in every stage it does, and a stage's stop all of them" do
      parar(lenta)
      manha = fila.ocorrencias.first
      calendario = CalendarioDeProducao.new
      expect([ calendario.horas(manha, "dublagem", maquina_id: lenta.id), calendario.horas(manha, "calandra", maquina_id: rapida.id) ]).to eq([ 0.0, 4.0 ])
      ExcecaoCalendario.destroy_all
      parar
      expect(calandra.inicio.to_date).to eq(quarta.to_date + 1)
    end

    it "gives a machine back from when it came back to work, in the turno too (Q7a)" do
      prender(rapida)
      parar(rapida).update!(voltou_em: quarta + 75.minutes, voltou_por: pessoa)
      expect([ calandra.maquina, calandra.inicio.strftime("%H:%M"), calandra.fim.strftime("%H:%M") ]).to eq([ rapida, "09:15", "09:45" ])
    end
  end

  describe ImpactoDaParada do
    before do
      pedido.update_columns(prazo_entrega: quarta.to_date)
      prender(rapida)
    end

    it "lists who comes to be late, why, and the pieces waiting — not saving anything" do
      parada = ExcecaoCalendario.new(nome: "Manutenção", data: quarta.to_date, data_fim: quarta.to_date + 1, etapa: "calandra")
      parada.paradas_das_maquinas.build(maquina: rapida)
      impacto = ImpactoDaParada.call(parada, fila)

      expect(impacto.empurrados.map { |e| [ e.pedido, e.passa_a_atrasar, e.para.strftime("%a %H:%M") ] }).to eq([ [ pedido, true, "Fri 08:30" ] ])
      expect(impacto.registro.except("calculado_em", "pedidos")).to eq("atrasam" => 1, "pioram" => 1, "esperam" => 1)
      expect(impacto.registro["pedidos"].first).to include("pedido_uuid" => pedido.uuid, "passa_a_atrasar" => true, "motivo" => "presa na Calandra 3", "prazo" => "2026-11-04")
      expect(ExcecaoCalendario.count).to eq(0)
    end
  end

  describe SalvarParada do
    let(:dados) { { nome: "Manutenção", data: "2026-11-04", data_fim: "2026-11-05", etapa: "calandra", maquina_uuids: [ rapida.uuid ] } }

    it "saves the stop with its machines, its author and its impact, telling each pushed pedido" do
      prender(rapida)
      resultado = SalvarParada.call(dados, fila: fila, maquinas: Maquina, user: pessoa)
      parada = resultado.parada.reload

      expect([ parada.maquinas, parada.user, parada.data_fim, parada.impacto["pioram"] ]).to eq([ [ rapida ], pessoa, Date.new(2026, 11, 5), 1 ])
      expect(pedido.eventos_pedido.where(tipo: "previsao_mudou").pluck(:recado)).to eq([ "qua 04/11 → sex 06/11" ])
    end

    it "refuses a machine of another stage, or one that doesn't exist, saving nothing" do
      epson = maquina("Epson", impressao_papel: 100)
      resultado = SalvarParada.call(dados.merge(maquina_uuids: [ epson.uuid ]), fila: fila, maquinas: Maquina, user: pessoa)
      expect([ resultado.erro, ExcecaoCalendario.count ]).to eq([ "Maquinas Epson don't do the Calandra", 0 ])
      expect { SalvarParada.call(dados.merge(maquina_uuids: [ "nope" ]), fila: fila, maquinas: Maquina, user: pessoa) }
        .to raise_error(ActiveRecord::RecordNotFound, /Machine\(s\) nope not found/)
    end
  end
end
