require "rails_helper"

# Painel 2/4a (decided 05/11/2026, Q5a): the median of the last 30 days'
# turnos with a baixa, per type × stage; nothing below 5 turnos.
RSpec.describe RitmoMedido do
  let!(:manha) { Turno.create!(nome: "Manhã", inicio: "06:00", fim: "14:00", dias: (0..6).to_a) }
  let(:pedido) { create(:pedido) }
  let(:agora) { Time.zone.parse("2026-11-20 18:00") }

  # A baixa as it was given: the line checks are not what this measures.
  def baixa(dia, metros, etapa: "impressao", hora: "10:00", alvo: pedido)
    BaixaProducao.new(uuid: SecureRandom.uuid, pedido: alvo, etapa: etapa, nivel: "pedido", linhas: [ "x" ], medida: metros, created_at: Time.zone.parse("2026-11-#{dia} #{hora}")).tap { |b| b.save!(validate: false) }
  end

  def medir
    described_class.call(CalendarioDeProducao.new, ate: agora)
  end

  it "has no measure below 5 turnos" do
    4.times { |i| baixa(10 + i, 40) }
    expect(medir).to eq({})
  end

  it "takes the median of each turno's measure over its hours" do
    # 8 h turnos: 16, 24, 40 (two baixas), 48 and 80 m → 2, 3, 5, 6, 10 m/h.
    [ [ 10, 16 ], [ 11, 24 ], [ 12, 30 ], [ 12, 10 ], [ 13, 48 ], [ 14, 80 ] ].each { |dia, metros| baixa(dia, metros) }
    medida = medir[%w[calcado impressao]]
    expect([ medida.por_hora, medida.turnos ]).to eq([ 5.0, 5 ])
  end

  it "leaves out the baixas outside any turno, the undone ones and those older than 30 days" do
    5.times { |i| baixa(10 + i, 40) }
    baixa(15, 400, hora: "20:00")
    baixa(16, 400).update_columns(desfeita_em: agora)
    baixa(1, 400).update_columns(created_at: agora - 31.days)
    expect(medir[%w[calcado impressao]].then { |m| [ m.por_hora, m.turnos ] }).to eq([ 5.0, 5 ])
  end

  it "measures each type × stage apart" do
    dtf = create(:pedido, tipo: "dtf")
    5.times { |i| baixa(10 + i, 40) }
    5.times { |i| baixa(10 + i, 80, alvo: dtf) }
    expect(medir.transform_values(&:por_hora)).to eq(%w[calcado impressao] => 5.0, %w[dtf impressao] => 10.0)
  end
end
