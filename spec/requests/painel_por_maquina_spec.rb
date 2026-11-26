require "rails_helper"
require_relative "../support/producao_tecido"

# Máquinas 5/5 (decided 25/11/2026, canvas "Máquinas", 13–15): the
# Linha do tempo's load opens a row per machine under its sector's ▸ (Q1a);
# the faixa's timeline names the machine after the stage (Q2a); the grid
# cell's hover says the machine and how it is there (Q3a). Not to a cliente
# final. A tecido pedido runs its Calandra (15,5 m) on the faster machine.
RSpec.describe "Painel por máquina", type: :request do
  include ActiveSupport::Testing::TimeHelpers

  # Wednesday, 10:00.
  before { travel_to Time.zone.parse("2026-11-04 10:00") }

  let!(:pedido) { pedido_tecido_confirmado.tap { |p| p.update_columns(confirmado_em: 2.hours.ago) } }
  let!(:lenta) { maquina("Calandra 2", calandra: 15.5, dublagem: 30) }
  let!(:rapida) { maquina("Calandra 3", calandra: 31) }

  before do
    Turno.create!(nome: "Dia", inicio: "00:00", fim: "23:59", dias: (0..6).to_a)
    RitmoProducao.create!(tipo: "tecido", etapa: "impressao", por_hora: 15.5)
  end

  def maquina(nome, **velocidades)
    Maquina.new(nome: nome).tap { |m| velocidades.each { |trabalho, por_hora| m.trabalhos.build(trabalho: trabalho.to_s, por_hora: por_hora) } }.tap(&:save!)
  end

  def html = Nokogiri::HTML(response.body)

  def parar(maquina, dias: 2)
    ExcecaoCalendario.new(nome: "Manutenção", data: Date.current, data_fim: Date.current + dias - 1, etapa: "calandra").tap do |parada|
      parada.paradas_das_maquinas.build(maquina: maquina)
      parada.save!
    end
  end

  def carga_da(maquina)
    html.at_css("[data-tempo-carga-maquina='#{maquina.nome}']")
  end

  def celulas(linha) = linha.css(".painel-tempo-carga").first(4).map { |c| c["class"][/painel-tempo-carga--(\w+)/, 1] }

  describe "the Linha do tempo's load" do
    it "gives the Estamparia's sector a ▸ and a hidden row per machine, the stopped one so" do
      parar(lenta)
      get painel_path(visao: "tempo")
      setor = html.at_css("[data-tempo-carga='estamparia']")
      expect(setor.at_css("[data-carga-abrir]")["data-setor"]).to eq("estamparia")
      expect([ carga_da(lenta)["hidden"].nil?, carga_da(lenta).at_css(".painel-tempo-lado").text.squish ]).to eq([ false, "Calandra 2 Calandra e Dublagem" ])
      # Monday and Tuesday are past; Wednesday and Thursday the Calandra 2 stops.
      expect([ celulas(carga_da(lenta)), celulas(carga_da(rapida)).first(2) ]).to eq([ %w[passado passado parada parada], %w[passado passado] ])
      expect(html.at_css("[data-tempo-carga='conferencia'] [data-carga-abrir]")).to be_nil
    end

    it "counts on each machine only its own pieces, today from now on" do
      linha = LinhaDoTempo.call([], fila: FilaDeProducao.call, de: Date.current, setores: %w[estamparia]).cargas.sole.maquinas
      quarta = linha.to_h { |l| [ l.maquina, l.celulas.first ] }
      # The Calandra waits for the Impressão (10:00–11:00): 30 min on the Calandra 3, of the 13 h 59 left.
      expect([ quarta[rapida].estado, quarta[rapida].percentual, quarta[lenta].estado ]).to eq([ :ok, 4, :livre ])
    end
  end

  it "names the machine after the stage in the faixa's timeline" do
    get painel_path
    raia = html.at_css("#painel_#{pedido.uuid} [data-tdp-raia='calandra']") || html.at_css("[data-tdp-raia='calandra']")
    expect(raia.text.squish).to eq("Calandra · Calandra 3")
    expect(html.at_css("[data-tdp-raia='impressao'] [data-tdp-maquina]")).to be_nil
  end

  it "says the machine in the grid cell's hover, held there and stopped" do
    get painel_path
    celula = -> { html.at_css("#painel_#{pedido.uuid} .painel-cel[data-coluna='estamparia']") }
    expect(celula.call["title"]).to end_with("na Calandra 3")

    MovimentoDaFila.create!(pedido: pedido, user: @usuario_logado, etapa: "calandra", setor: "estamparia", de_maquina: rapida, para_maquina: lenta)
    parar(lenta)
    get painel_path
    expect(celula.call["title"]).to end_with("presa na Calandra 2 · parada até qui 05/11")
  end

  # The machines are the factory's: a cliente final sees no load (as before),
  # no machine in the faixa nor in the hover.
  it "shows a cliente final no machine" do
    funcao = create(:funcao, :para_cliente, niveis: (Autorizacao::AREAS - Autorizacao::AREAS_DA_EQUIPE).index_with(1))
    entrar_como(create(:vinculo, user: create(:user), funcao: funcao, client: pedido.client).user)
    get painel_path
    expect(html.at_css("#painel_#{pedido.uuid}")).to be_present
    expect([ html.css("[data-tdp-maquina]").size, html.css("[data-tempo-carga-maquina]").size, response.body.include?("Calandra 3") ]).to eq([ 0, 0, false ])
  end
end
