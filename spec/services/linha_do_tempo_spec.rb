require "rails_helper"

# Painel 2/4c (decided 05–07/11/2026): 14 days, each pedido a bar to its
# previsão, the groups and their order (Q6a), the days without turno, and
# each sector's load per day — today only from now on (Q2a), none for a
# cliente final (Q4a).
RSpec.describe LinhaDoTempo do
  # Wednesday, in the Manhã; the window from Monday 02/11 to Sunday 15/11.
  let(:agora) { Time.zone.parse("2026-11-04 10:00") }
  let(:de) { Date.new(2026, 11, 2) }
  let(:manha) { Turno.new(nome: "Manhã", inicio: "08:00", fim: "12:00", dias: (1..5).to_a) }
  let(:tarde) { Turno.new(nome: "Tarde", inicio: "13:00", fim: "17:00", dias: (1..5).to_a) }
  let(:excecoes) { [ ExcecaoCalendario.new(data: Date.new(2026, 11, 10), nome: "Recesso"), ExcecaoCalendario.new(data: Date.new(2026, 11, 6), nome: "Faca nova", etapa: "corte") ] }
  let(:calendario) { CalendarioDeProducao.new(turnos: [ manha, tarde ], excecoes: excecoes) }
  let(:setores) { {} }
  let(:fila) do
    instance_double(FilaDeProducao, agora: agora).tap do |f|
      allow(f).to receive(:do_setor) { |setor| setores.fetch(setor, []) }
    end
  end

  def previsao(fim, se_confirmar: false, motivo: nil)
    vezes = fim == :pronta ? [] : [ FilaDeProducao::Vez.new(fim: fim, motivo: ("previsão quando Oxford entrar" unless fim), trechos: []) ]
    FilaDeProducao::Previsao.new(vezes: vezes, se_confirmar: se_confirmar, motivo: motivo)
  end

  def linha(id, inicio:, previsao: nil, prazo: nil, status: "confirmado", entregue_em: nil)
    pedido = instance_double(Pedido, id: id, status: status, entregue_em: entregue_em)
    instance_double(LinhaDoPainel, pedido: pedido, previsao: previsao, inicio: inicio, chegada: inicio, prazo: prazo).tap do |l|
      allow(l).to receive(:com_reposicoes).and_return([ l ])
    end
  end

  def tempo(linhas, entregues: [], ordem: "chegada", **opcoes)
    described_class.call(linhas, fila: fila, de: de, entregues: entregues, agora: agora, calendario: calendario, ordem: ordem, **opcoes)
  end

  def barras(t)
    t.grupos.to_h { |g| [ g.chave, g.barras.map { |b| b.linha.pedido.id } ] }
  end

  it "lays 14 days, today and the ones the whole factory doesn't work" do
    dias = tempo([]).dias
    expect([ dias.size, dias.find(&:hoje).data ]).to eq([ 14, agora.to_date ])
    # The weekends and the factory's recess; the Corte's stop is only the Corte's.
    expect(dias.select(&:sem_turno).map { |d| d.data.day }).to eq([ 7, 8, 10, 14, 15 ])
  end

  it "draws a bar done up to now, foreseen to the deadline, and late past it" do
    barra = tempo([ linha(:atrasa, inicio: Time.zone.parse("2026-11-03 10:00"), previsao: previsao(Time.zone.parse("2026-11-06 13:00")), prazo: Date.new(2026, 11, 5)) ])
            .grupos.first.barras.sole

    expect([ barra.feito, barra.previsto, barra.atraso, barra.prazo_em ]).to eq([ [ 10.12, 7.14 ], [ 17.26, 11.31 ], [ 28.57, 3.87 ], 28.57 ])
    expect([ barra.dias_de_atraso, barra.comecou_antes?, barra.espera ]).to eq([ 1, false, false ])
  end

  it "groups the queue, the ones without previsão, the drafts and the delivered inside the window" do
    linhas = [ linha(:fila, inicio: agora - 1.day, previsao: previsao(agora + 1.day)), linha(:pronta, inicio: agora - 2.days, previsao: previsao(:pronta)),
               linha(:sem, inicio: agora - 1.day, previsao: previsao(nil)), linha(:rascunho, inicio: agora - 3.days, previsao: previsao(agora + 2.days, se_confirmar: true)),
               # Asked for by the Etapas view: it comes again among the window's delivered ones.
               linha(:entregue_7_dias, inicio: agora - 9.days, status: "entregue", entregue_em: agora - 1.day) ]
    entregues = [ linha(:antes, inicio: agora - 5.days, status: "entregue", entregue_em: agora - 2.days), linha(:depois, inicio: agora - 4.days, status: "entregue", entregue_em: agora - 1.hour) ]

    t = tempo(linhas, entregues: entregues)
    expect(barras(t)).to eq("em_producao" => %i[pronta fila], "sem_previsao" => %i[sem], "pendentes" => %i[rascunho], "entregues" => %i[depois antes])
    pronta = t.grupos.first.barras.first
    expect([ pronta.fim, pronta.previsto, t.grupos.third.barras.sole.se_confirmar ]).to eq([ agora, nil, [ 17.26, 14.29 ] ])
  end

  it "orders the queue by arrival, previsão or deadline" do
    cedo = linha(:cedo, inicio: agora - 2.days, previsao: previsao(agora + 3.days), prazo: Date.new(2026, 11, 12))
    tarde = linha(:tarde, inicio: agora - 1.day, previsao: previsao(agora + 1.day))
    apertado = linha(:apertado, inicio: agora - 1.hour, previsao: previsao(agora + 2.days), prazo: Date.new(2026, 11, 6))

    ordens = %w[chegada previsao prazo].map { |ordem| barras(tempo([ tarde, apertado, cedo ], ordem: ordem))["em_producao"] }
    expect(ordens).to eq([ %i[cedo tarde apertado], %i[tarde apertado cedo], %i[apertado cedo tarde] ])
  end

  # Q16a: going back in time shows only the record.
  it "shows only the record in the past, and nothing past the 90 days of the queue" do
    passado = described_class.call([ linha(:sem, inicio: agora - 30.days, previsao: previsao(nil)), linha(:ja, inicio: agora - 31.days, previsao: previsao(agora + 1.day)) ],
                                   fila: fila, de: de - 28, agora: agora, calendario: calendario)
    expect([ passado.no_passado?, barras(passado), passado.grupos.first.barras.sole.comecou_antes?, passado.agora_em ]).to eq([ true, { "em_producao" => %i[ja] }, true, nil ])
    expect(described_class.call([], fila: fila, de: agora.to_date + 91, agora: agora, calendario: calendario).depois_da_fila?).to be(true)
    # Two weeks ahead, a pedido that ends before them is not there.
    adiante = described_class.call([ linha(:acaba, inicio: agora - 1.day, previsao: previsao(agora + 2.days)), linha(:segue, inicio: agora - 1.day, previsao: previsao(agora + 20.days)) ],
                                   fila: fila, de: de + 14, agora: agora, calendario: calendario)
    expect(barras(adiante)).to eq("em_producao" => %i[segue])
  end

  describe "the load per day" do
    def trecho(inicio, horas)
      ocorrencia = calendario.ocorrencias(de: inicio, ate: inicio + 1.minute).sole
      FilaDeProducao::Trecho.new(ocorrencia: ocorrencia, inicio: inicio, fim: inicio + horas.hours)
    end

    def vez(*trechos)
      FilaDeProducao::Vez.new(trechos: trechos)
    end

    let(:quinta) { Time.zone.parse("2026-11-05 08:00") }
    let(:setores) do
      { "impressao" => [ vez(trecho(agora, 2)), vez(trecho(quinta, 4), trecho(quinta + 5.hours, 2)) ],
        "estamparia" => [ vez(trecho(quinta, 4), trecho(quinta + 5.hours, 4)) ], "corte" => [ vez(trecho(quinta, 4), trecho(quinta + 5.hours, 3)) ] }
    end

    def celulas(t, setor)
      t.cargas.find { |c| c.setor == setor }.celulas.first(6).map { |c| [ c.estado, c.percentual ] }
    end

    it "fills each sector's turnos, today only from now on, never over 100%" do
      t = tempo([])
      # Today: 2 h of the 2 left in the Manhã + 4 of the Tarde. Thursday: 6 h of 8.
      expect(celulas(t, "impressao")).to eq([ [ :passado, nil ], [ :passado, nil ], [ :ok, 33 ], [ :ok, 75 ], [ :livre, 0 ], [ :sem_turno, nil ] ])
      expect(celulas(t, "estamparia")[3]).to eq([ :cheio, 100 ])
      expect(celulas(t, "corte").values_at(3, 4)).to eq([ [ :alto, 88 ], [ :parada, nil ] ])
    end

    it "says today's turnos are over, and gives a cliente final none" do
      expect(described_class.call([], fila: fila, de: de, agora: agora.change(hour: 18), calendario: calendario).cargas.first.celulas[2].estado).to eq(:encerrado)
      expect(tempo([], cliente_final: true).cargas).to eq([])
    end
  end
end
