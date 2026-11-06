require "rails_helper"

# Painel 2/4a (decided 05/11/2026): the dono registers the turnos, the
# calendar's exceptions, confirms the national holidays and types each
# stage's rhythm; the Painel shows the turno on now.
RSpec.describe "Turnos, calendário e ritmo", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  def turno_params(nome, inicio, fim, dias = %w[1 2 3 4 5])
    { turno: { nome: nome, inicio: inicio, fim: fim, dias: [ "" ] + dias } }
  end

  describe "turnos" do
    it "creates, changes and trashes a turno" do
      post parametros_turnos_path, params: turno_params("Manhã", "06:00", "14:00")
      turno = Turno.sole
      expect([ turno.horario, turno.dias, flash[:notice] ]).to eq([ "06:00–14:00", [ 1, 2, 3, 4, 5 ], "Turno Manhã saved." ])
      patch parametros_turno_path(turno), params: turno_params("Manhã", "07:00", "15:00", %w[1 2 3 4 5 6])
      expect([ turno.reload.horario, turno.dias.size ]).to eq([ "07:00–15:00", 6 ])
      delete parametros_turno_path(turno)
      expect([ turno.reload.excluido?, flash[:notice] ]).to eq([ true, "Turno Manhã moved to the trash." ])
    end

    it "refuses one that overlaps, saying where" do
      post parametros_turnos_path, params: turno_params("Manhã", "06:00", "14:00")
      post parametros_turnos_path, params: turno_params("Tarde", "13:00", "22:00")
      expect([ Turno.count, flash[:alert] ]).to match([ 1, include("overlaps Manhã 06:00–14:00 (seg a sex) on seg 13:00") ])
    end

    it "lists the turnos, the year's exceptions and the suggested holidays" do
      Turno.create!(nome: "Manhã", inicio: "06:00", fim: "14:00", dias: [ 1 ])
      ExcecaoCalendario.create!(data: Date.new(2026, 11, 13), nome: "Calandra parada", etapa: "calandra")
      get parametros_turnos_path(ano: 2026)
      expect(response.body).to include('data-turno="Manhã"', "sex 13/11", "Calandra · dia inteiro", 'data-feriado="2026-11-20"', "ponto facultativo")
    end

    it "brings a trashed turno back from the Lixeira only if its hours are free" do
      turno = Turno.create!(nome: "Manhã", inicio: "06:00", fim: "14:00", dias: [ 1 ])
      turno.excluir!(changed_by: "spec")
      Turno.create!(nome: "Cedo", inicio: "07:00", fim: "12:00", dias: [ 1 ])
      # The Lixeira lists it with its icon (it answered 500 without one).
      get lixeira_path
      expect(response.body).to include('data-tipo="turnos"', "icons/lixeira/turno")
      post restaurar_lixeira_path(tipo: "turnos", id: turno.uuid)
      expect([ turno.reload.excluido?, flash[:alert] ]).to match([ true, include("overlaps Cedo") ])
    end
  end

  describe "the calendar" do
    let!(:tarde) { Turno.create!(nome: "Tarde", inicio: "14:00", fim: "22:00", dias: (1..5).to_a) }

    it "adds an exception for one stage and turno, and removes it" do
      post parametros_excecoes_path, params: { excecao: { nome: "Calandra parada", data: "2026-11-13", turno_uuid: tarde.uuid, etapa: "calandra" } }
      excecao = ExcecaoCalendario.sole
      expect([ excecao.turno, excecao.etapa, excecao.origem, flash[:notice] ]).to eq([ tarde, "calandra", "manual", "Calandra parada (13/11/2026) saved." ])
      delete parametros_excecao_path(excecao)
      expect(ExcecaoCalendario.count).to eq(0)
    end

    it "answers the error of a bad exception" do
      post parametros_excecoes_path, params: { excecao: { nome: "", data: "2026-11-13", etapa: "pintura" } }
      expect([ ExcecaoCalendario.count, flash[:alert] ]).to match([ 0, include("Nome can't be blank", '"pintura" is not a production stage') ])
    end

    it "confirms a national holiday and takes it back" do
      post feriado_parametros_excecoes_path, params: { data: "2026-11-20", confirmado: "1" }
      post feriado_parametros_excecoes_path, params: { data: "2026-11-20", confirmado: "1" }
      expect(ExcecaoCalendario.where(origem: "feriado").pluck(:data, :nome)).to eq([ [ Date.new(2026, 11, 20), "Dia Nacional de Zumbi e da Consciência Negra" ] ])
      post feriado_parametros_excecoes_path, params: { data: "2026-11-20", confirmado: "0" }
      expect(ExcecaoCalendario.count).to eq(0)
    end

    it "refuses a day that is not a national holiday, and one that is not a date" do
      post feriado_parametros_excecoes_path, params: { data: "2026-11-19", confirmado: "1" }
      expect(flash[:alert]).to eq("19/11/2026 is not a national holiday; expected one of the suggested days")
      post feriado_parametros_excecoes_path, params: { data: "amanhã", confirmado: "1" }
      expect(flash[:alert]).to eq('Date "amanhã" is not a date like 2026-11-20')
    end
  end

  describe "the rhythm" do
    it "lists every type × stage with its unit, and saves the typed and fixed ones" do
      get edit_parametros_ritmos_path
      expect(response.body).to include('data-ritmo="calcado:impressao"', 'data-ritmo="dtf:corte"', 'data-ritmo="tecido:calandra"', "unidades/h", "not set")
      patch parametros_ritmos_path, params: { ritmos: { calcado: { impressao: { por_hora: "5,5", fixar_informado: "1" } }, dtf: { corte: { por_hora: "" } } } }
      expect(RitmoProducao.pluck(:tipo, :etapa, :por_hora, :fixar_informado)).to eq([ [ "calcado", "impressao", 5.5, true ] ])
      expect(flash[:notice]).to eq("Production rhythm saved.")
    end

    it "refuses a rhythm of 0, naming the stage" do
      patch parametros_ritmos_path, params: { ritmos: { calcado: { corte: { por_hora: "0" } } } }
      expect([ RitmoProducao.count, flash[:alert] ]).to eq([ 0, "Corte (Calçado): Por hora must be more than 0 per hour (blank = not set)" ])
    end

    # Painel 2/4a2 (decided 06/11/2026): the calçado's Corte types the cutting machine.
    it "shows the Corte's machine with its defaults, and saves the typed ones (blank = the default)" do
      get edit_parametros_ritmos_path
      linha = response.body[/data-ritmo="calcado:corte".*?<\/tr>/m]
      expect(linha).to include('name="ritmos[calcado][corte][velocidade_mm_s]"', 'placeholder="100"', 'placeholder="2"', 'placeholder="50"', "machine time only", "100%")
      expect(linha).not_to include("[por_hora]")
      patch parametros_ritmos_path, params: { ritmos: { calcado: { corte: { velocidade_mm_s: "120", pinca_s: "1,5", preparo_min: "", troca_min: "" } } } }
      ritmo = RitmoProducao.sole
      expect([ ritmo.velocidade_mm_s, ritmo.pinca_s, ritmo.preparo_min, ritmo.maquina(:preparo_min) ]).to eq([ 120, 1.5, nil, 5.0 ])
    end

    it "refuses a machine parameter of 0, naming it" do
      patch parametros_ritmos_path, params: { ritmos: { calcado: { corte: { troca_min: "0" } } } }
      expect([ RitmoProducao.count, flash[:alert] ]).to eq([ 0, "Corte (Calçado): Troca min must be more than 0 (blank = the default)" ])
    end

    it "warns of the cortes not measured by layer yet" do
      create(:tamanho, arquivo: create(:arquivo, :corte), linhas_por_cor: nil)
      create(:tamanho, arquivo: create(:arquivo, :corte), linhas_por_cor: {})
      get edit_parametros_ritmos_path
      expect(response.body).to include("1 corte file is not measured by layer yet")
    end

    it "shows the measured rhythm in use once there are enough turnos" do
      Turno.create!(nome: "Dia", inicio: "00:00", fim: "23:59", dias: (0..6).to_a)
      RitmoProducao.create!(tipo: "calcado", etapa: "impressao", por_hora: 5)
      pedido = create(:pedido)
      5.times { |i| BaixaProducao.new(uuid: SecureRandom.uuid, pedido: pedido, etapa: "impressao", nivel: "pedido", linhas: [ "x" ], medida: 47.92, created_at: (i + 1).days.ago).save!(validate: false) }
      get edit_parametros_ritmos_path
      linha = response.body[/data-ritmo="calcado:impressao".*?<\/tr>/m]
      expect(linha).to include("2 m/h", "5 turnos", "measured")
    end
  end

  describe "the Painel's header" do
    it "shows the turno on now, or the next one" do
      Turno.create!(nome: "Manhã", inicio: "06:00", fim: "14:00", dias: (0..6).to_a)
      travel_to(Time.zone.parse("2026-11-04 10:40")) { get painel_path }
      expect(response.body).to include("qua 04/11 · 10:40 · turno Manhã (06:00–14:00)")
      travel_to(Time.zone.parse("2026-11-04 15:00")) { get painel_path }
      expect(response.body).to include("qua 04/11 · 15:00 · fora de turno · próximo: Manhã amanhã às 06:00")
    end

    it "says nothing without turnos" do
      get painel_path
      expect(response.body).not_to include("data-painel-agora")
    end
  end
end
