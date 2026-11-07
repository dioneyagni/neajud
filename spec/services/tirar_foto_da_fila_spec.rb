require "rails_helper"
require_relative "../support/producao_tecido"

# Painel 3/4b (decided 07/11/2026, Q2a–Q6a): the photo of each turno's
# queue, and the virada against the photo before. A tecido pedido here
# prints 15,5 m in an hour and runs them on the Calandra in half an hour;
# the factory works a Manhã, 08:00–12:00, on weekdays.
RSpec.describe TirarFotoDaFila do
  include ActiveSupport::Testing::TimeHelpers

  let(:sem_falta) { instance_double(AguardandoMaterial, do_pedido: []) }
  # Wednesday and Thursday, as the Manhã starts.
  let(:quarta) { Time.zone.parse("2026-11-04 08:00") }
  let(:quinta) { Time.zone.parse("2026-11-05 08:00") }
  let!(:primeiro) { tecido(quarta - 3.hours) }
  let!(:segundo) { tecido(quarta - 2.hours) }
  let!(:terceiro) { tecido(quarta - 1.hour) }

  before do
    Turno.create!(nome: "Manhã", inicio: "08:00", fim: "12:00", dias: (1..5).to_a)
    RitmoProducao.create!(tipo: "tecido", etapa: "impressao", por_hora: 15.5)
    RitmoProducao.create!(tipo: "tecido", etapa: "calandra", por_hora: 31)
  end

  def tecido(confirmado_em)
    pedido_tecido_confirmado.tap { |pedido| pedido.update_columns(confirmado_em: confirmado_em) }
  end

  def foto(agora)
    travel_to(agora) { described_class.call(agora: agora, aguardando: sem_falta) }
  end

  it "keeps every stage of the queue: its place, its end, the pedido's previsão and its pieces" do
    tirada = foto(quarta)
    vezes = tirada.vezes.order(:id).map { |v| [ v.pedido, v.etapa, v.posicao, v.fim, v.previsao ] }

    expect([ tirada.turno_nome, tirada.data, tirada.inicio, tirada.fim ]).to eq([ "Manhã", quarta.to_date, quarta, quarta + 4.hours ])
    expect(vezes.first(2)).to eq([ [ primeiro, "impressao", 1, quarta + 1.hour, quarta + 1.5.hours ], [ primeiro, "calandra", 1, quarta + 1.5.hours, quarta + 1.5.hours ] ])
    expect(vezes.size).to eq(6)
    expect(tirada.vezes.find_by(pedido: terceiro, etapa: "impressao").trechos).to eq([ { "inicio" => (quarta + 2.hours).iso8601, "fim" => (quarta + 3.hours).iso8601 } ])
  end

  it "takes one per turno: none twice, none between turnos" do
    foto(quarta)

    expect(foto(quarta + 2.hours)).to be_nil
    expect(foto(quarta + 5.hours)).to be_nil
    expect(FotoDaFila.count).to eq(1)
  end

  it "deletes the photos past 7 days, with their stages" do
    velha = foto(quarta - 8.days)
    foto(quarta)

    expect(FotoDaFila.exists?(velha.id)).to be(false)
    expect(VezDaFoto.where(foto_da_fila_id: velha.id)).to be_empty
  end

  describe "the virada" do
    before do
      primeiro.update!(prazo_entrega: quarta.to_date)
      segundo.update!(prazo_entrega: quinta.to_date)
    end

    # Nothing was done on Wednesday: every previsão went to Thursday.
    it "tells each pedido whose previsão went to a later day, which stages didn't end, and who came to be late" do
      foto(quarta)
      foto(quinta)
      viradas = ViradaDoPedido.order(:id).map { |v| [ v.pedido, v.turno_nome, v.de, v.para.to_date, v.passou_a_atrasar ] }

      expect(viradas).to eq([ [ primeiro, "Manhã", quarta + 1.5.hours, quinta.to_date, true ], [ segundo, "Manhã", quarta + 2.5.hours, quinta.to_date, false ],
                              [ terceiro, "Manhã", quarta + 3.5.hours, quinta.to_date, false ] ])
      expect(ViradaDoPedido.first.nao_terminaram.first).to eq("pedido" => primeiro.uuid.first(8), "etapa" => "Impressão", "veio_de" => "Manhã")
      expect(ViradaDoPedido.first.nao_terminaram.size).to eq(6)
      # Each pedido's own stages first.
      expect(ViradaDoPedido.last.nao_terminaram.first(2).map { |e| [ e["pedido"], e["etapa"] ] }).to eq([ [ terceiro.uuid.first(8), "Impressão" ], [ terceiro.uuid.first(8), "Calandra" ] ])
      # Q6a: the cliente final's, from no one.
      expect(EventoPedido.where(tipo: "previsao_mudou").map { |e| [ e.pedido, e.recado, e.user ] }).to include([ primeiro, "qua 04/11 → qui 05/11", nil ])
    end

    it "tells nothing when the day stays" do
      foto(quarta)
      Turno.create!(nome: "Tarde", inicio: "13:00", fim: "17:00", dias: (1..5).to_a)
      foto(quarta + 5.hours)

      expect([ ViradaDoPedido.count, EventoPedido.count ]).to eq([ 0, 0 ])
    end

    it "doesn't tell again what a move in the queue already told during the turno" do
      foto(quarta)
      travel_to(quarta + 1.hour) do
        MovimentoDaFila.create!(pedido: terceiro, user: create(:user), etapa: "impressao", setor: "impressao", de: 3, para: 3,
                                empurrados: [ { "pedido_id" => primeiro.id, "de" => (quarta + 1.5.hours).iso8601, "para" => (quinta + 1.hour).iso8601 } ])
      end
      foto(quinta)

      expect(ViradaDoPedido.pluck(:pedido_id)).to eq([ segundo.id, terceiro.id ])
    end
  end
end
