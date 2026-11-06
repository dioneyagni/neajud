require "rails_helper"
require_relative "../support/producao_calcado"

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
    expect([ medida.valor, medida.turnos ]).to eq([ 5.0, 5 ])
  end

  it "leaves out the baixas outside any turno, the undone ones and those older than 30 days" do
    5.times { |i| baixa(10 + i, 40) }
    baixa(15, 400, hora: "20:00")
    baixa(16, 400).update_columns(desfeita_em: agora)
    baixa(1, 400).update_columns(created_at: agora - 31.days)
    expect(medir[%w[calcado impressao]].then { |m| [ m.valor, m.turnos ] }).to eq([ 5.0, 5 ])
  end

  it "measures each type × stage apart" do
    dtf = create(:pedido, tipo: "dtf")
    5.times { |i| baixa(10 + i, 40) }
    5.times { |i| baixa(10 + i, 80, alvo: dtf) }
    expect(medir.transform_values(&:valor)).to eq(%w[calcado impressao] => 5.0, %w[dtf impressao] => 10.0)
  end

  # Painel 2/4a2 (decided 06/11/2026): a stage whose rhythm counts something
  # else measures it from the lines its baixas covered.
  describe "converted from the baixa's lines" do
    let(:calcado) { pedido_calcado_confirmado }

    def linhas(etapa) = LinhasDeProducao.call(calcado, EtapasProducao.etapa("calcado", etapa))

    def baixas_de(etapa, chaves)
      5.times { |i| baixa(10 + i, 20, etapa: etapa, alvo: calcado).update_columns(linhas: chaves) }
    end

    it "measures the calçado's Estamparia in its lines' paper meters per hour" do
      chaves = linhas("estamparia").map(&:chave)
      papel = linhas("impressao").select { |l| chaves.include?(l.chave) }.sum { |l| l.esperado.to_f }
      baixas_de("estamparia", chaves)
      expect(medir[%w[calcado estamparia]].valor).to eq((papel / 8).round(3))
    end

    it "measures the calçado's Corte as the machine's share of the turno" do
      corte = linhas("corte")
      corte.each { |linha| linha.tamanho.update!(perimeter_mm: 1000, linhas_por_cor: {}) }
      baixas_de("corte", corte.map(&:chave))
      horas = TempoDoCorte.call(corte, RitmoProducao.de("calcado", "corte")).horas
      expect(medir[%w[calcado corte]].valor).to eq((horas / 8).round(3))
    end
  end
end
