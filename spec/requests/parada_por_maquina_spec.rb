require "rails_helper"

# Máquinas 3/5a (decided 24/11/2026, canvas "Máquinas", 6–7): the Turnos
# page saves a stop of de…até with some of its stage's machines and says
# what it did (Q3a); the list keeps who made it, what it stops — the other
# stages too (Q1a) — and its impact (Q4a); "voltou a funcionar" ends one
# under way (Q7a); one that ended stays, with no button.
RSpec.describe "Parada por máquina", type: :request do
  def html = Nokogiri::HTML(response.body)

  def maquina(nome, **velocidades)
    Maquina.new(nome: nome).tap { |m| velocidades.each { |trabalho, por_hora| m.trabalhos.build(trabalho: trabalho.to_s, por_hora: por_hora) } }.tap(&:save!)
  end

  let!(:calandra_2) { maquina("Calandra 2", calandra: 40, dublagem: 30) }
  let!(:calandra_3) { maquina("Calandra 3", calandra: 40) }
  let(:hoje) { Date.current }

  # The <br> between a cell's lines read as a space.
  def linha(nome) = html.at_css("tr[data-excecao='#{nome}']").tap { |tr| tr&.css("br")&.each { |br| br.replace(" ") } }

  it "offers each stage's machines in the window, and saves a stop of some of them for days" do
    get parametros_turnos_path
    caixa = html.at_css("fieldset.parada-maquinas[data-etapa='calandra']")
    expect([ caixa.css("label").map { |l| l.text.squish }, caixa["disabled"].nil? ]).to eq([ [ "Calandra 2 · Calandra e Dublagem", "Calandra 3" ], false ])

    post parametros_excecoes_path, params: { excecao: { nome: "Manutenção da Calandra 2", data: hoje.iso8601, data_fim: (hoje + 2).iso8601, etapa: "calandra", maquina_uuids: [ calandra_2.uuid ] } }
    parada = ExcecaoCalendario.sole
    expect([ parada.maquinas, parada.user, parada.impacto["atrasam"] ]).to eq([ [ calandra_2 ], @usuario_logado, 0 ])
    follow_redirect!
    expect(html.at_css("[data-parada-aviso]").text.squish).to include("Manutenção da Calandra 2 (#{Turno.dia_com_semana(hoje)} – #{Turno.dia_com_semana(hoje + 2)}) salva. Ninguém passa a atrasar.")
    expect(linha("Manutenção da Calandra 2").css("td").map { |td| td.text.squish }.first(4))
      .to eq([ "#{Turno.dia_com_semana(hoje)} – #{Turno.dia_com_semana(hoje + 2)}", "Manutenção da Calandra 2 #{@usuario_logado.nome} · #{I18n.l(parada.created_at, format: "%d/%m %H:%M")}",
               "Calandra › Calandra 2 · dia inteiro para também na Dublagem", "ninguém atrasou" ])
  end

  it "ends a stop under way when it came back to work, keeping when and who; one that ended has no button" do
    parada = ExcecaoCalendario.create!(nome: "Calandra 3 sem feltro", data: hoje, etapa: "calandra").tap { |p| p.paradas_das_maquinas.create!(maquina: calandra_3) }
    get parametros_turnos_path
    expect(linha("Calandra 3 sem feltro").css("button").map(&:text)).to eq([ "Voltou a funcionar", "Remover" ])

    patch voltou_parametros_excecao_path(parada)
    expect([ parada.reload.voltou_por, flash[:notice] ]).to eq([ @usuario_logado, "Calandra 3 sem feltro: voltou a funcionar." ])
    get parametros_turnos_path
    expect([ linha("Calandra 3 sem feltro").css("button").size, linha("Calandra 3 sem feltro").at_css("[data-voltou]").text ])
      .to eq([ 0, "voltou #{Turno.dia_com_semana(hoje)} #{parada.voltou_em.strftime("%H:%M")} · #{@usuario_logado.nome}" ])

    patch voltou_parametros_excecao_path(parada)
    expect(flash[:alert]).to eq("Calandra 3 sem feltro already came back to work; expected a stop under way")
    delete parametros_excecao_path(parada)
    expect([ ExcecaoCalendario.count, flash[:alert] ]).to eq([ 1, "Calandra 3 sem feltro ended: it stays on the record" ])
  end

  it "shows the old stops, saved before the impact was kept, with a dash" do
    ExcecaoCalendario.create!(nome: "Recesso", data: hoje + 10)
    get parametros_turnos_path
    expect(linha("Recesso").at_css("[data-impacto-da-parada]").text.squish).to eq("—")
  end
end
