require "rails_helper"

# Painel 2/4b (Q3a, Q4a, Q6a): a row goes where its next piece of work is;
# inside a block by that time, the late ones ahead of the same time.
RSpec.describe BlocosNoTempo do
  # Wednesday, in the Manhã.
  let(:agora) { Time.zone.parse("2026-11-04 10:00") }
  let(:manha) { Turno.new(nome: "Manhã", inicio: "08:00", fim: "12:00") }
  let(:tarde) { Turno.new(nome: "Tarde", inicio: "13:00", fim: "17:00") }

  def ocorrencia(turno, data, inicio, fim)
    CalendarioDeProducao::Ocorrencia.new(turno: turno, data: data, inicio: Time.zone.parse("#{data} #{inicio}"), fim: Time.zone.parse("#{data} #{fim}"))
  end

  # A row whose next piece starts at `as` (nil: no previsão), in that turno.
  def linha(nome, as: nil, turno: manha, se_confirmar: false, status: "confirmado", vai_atrasar: false, pronta: false, chegada: agora)
    data = as&.to_date
    vezes = pronta ? [] : [ FilaDeProducao::Vez.new(fim: as && as + 1.hour, trechos: as ? [ FilaDeProducao::Trecho.new(ocorrencia: ocorrencia(turno, data, turno.inicio, turno.fim), inicio: as, fim: as + 1.hour) ] : []) ]
    previsao = status == "rascunho" ? nil : FilaDeProducao::Previsao.new(vezes: vezes, se_confirmar: se_confirmar)
    instance_double(LinhaDoPainel, pedido: instance_double(Pedido, status: status, id: nome), previsao: previsao, vai_atrasar?: vai_atrasar,
                                   atrasado?: false, pendencia?: false, prazo: nil, chegada: chegada).tap do |l|
      allow(l).to receive(:com_reposicoes).and_return([ l ])
    end
  end

  def blocos(linhas, **opcoes)
    described_class.call(linhas, agora: agora, **opcoes).map { |b| [ b.chave, b.nome, b.linhas.map { |l| l.pedido.id } ] }
  end

  it "puts the turno under way, today's next turnos, tomorrow and the days apart, then the fixed blocks" do
    linhas = [ linha(:depois, as: Time.zone.parse("2026-11-09 08:00")), linha(:tarde, as: Time.zone.parse("2026-11-04 13:00"), turno: tarde),
               linha(:agora, as: Time.zone.parse("2026-11-04 10:30")), linha(:amanha, as: Time.zone.parse("2026-11-05 08:00")),
               linha(:sem, as: nil), linha(:entregar, pronta: true), linha(:rascunho, status: "rascunho"), linha(:enviado, se_confirmar: true, as: agora) ]

    expect(blocos(linhas)).to eq([
      [ "agora", "Agora · Manhã (08:00–12:00)", %i[entregar agora] ],
      [ "turno:2026-11-04T13:00:00-03:00", "Hoje · Tarde (13:00–17:00)", %i[tarde] ],
      [ "amanha", "Amanhã · qui 05/11", %i[amanha] ],
      [ "dia:2026-11-09", "seg 09/11 · em 5 dias", %i[depois] ],
      [ "sem_previsao", "Sem previsão", %i[sem] ],
      [ "pendentes", "Pendentes de início", %i[rascunho enviado] ]
    ])
  end

  # Q6a: of the same time, the one that will be late first.
  it "orders a block by the next piece's time, the late ones ahead of the same time" do
    cedo = linha(:cedo, as: Time.zone.parse("2026-11-04 10:15"))
    vai_atrasar = linha(:vai_atrasar, as: Time.zone.parse("2026-11-04 10:30"), vai_atrasar: true)
    no_prazo = linha(:no_prazo, as: Time.zone.parse("2026-11-04 10:30"), chegada: agora - 1.day)
    expect(blocos([ no_prazo, vai_atrasar, cedo ]).first.last).to eq(%i[cedo vai_atrasar no_prazo])
  end

  # Q4a: days only, no turnos, for a cliente final.
  it "shows a cliente final days only" do
    linhas = [ linha(:agora, as: Time.zone.parse("2026-11-04 10:30")), linha(:tarde, as: Time.zone.parse("2026-11-04 13:00"), turno: tarde),
               linha(:amanha, as: Time.zone.parse("2026-11-05 08:00")) ]
    expect(blocos(linhas, cliente_final: true).map(&:first)).to eq(%w[hoje amanha sem_previsao pendentes])
    expect(blocos(linhas, cliente_final: true).first.last).to eq(%i[agora tarde])
  end

  it "adds the delivered block only when asked" do
    expect(blocos([ linha(:entregue, status: "entregue") ], entregues: true).last).to eq([ "entregues", "Entregues (7 dias)", %i[entregue] ])
    expect(blocos([]).map(&:first)).to eq(%w[agora sem_previsao pendentes])
  end
end
