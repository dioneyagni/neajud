require "rails_helper"
require_relative "../support/producao_tecido"

# Máquinas 4/5a (decided 20–24/11/2026): the tecido's Calandra page asks
# which machine each baixa was done on (Q4a), opening on the one suggested
# — fetched apart, so the page doesn't build the queue —, says it on the
# line done and in the baixas' history; a baixa on another machine than the
# held one moves the hold (Q1a) and the Histórico da programação says so.
RSpec.describe "Baixa com a máquina", type: :request do
  let!(:lenta) { maquina("Calandra 2") }
  let!(:rapida) { maquina("Calandra 3") }
  let(:pedido) { pedido_tecido_confirmado }
  let(:html) { Nokogiri::HTML(response.body) }

  before { RegistrarBaixaService.call(pedido, etapa: "impressao", nivel: "pedido", medida: "15,5", confirmar: true) }

  def maquina(nome)
    Maquina.new(nome: nome).tap { |m| m.trabalhos.build(trabalho: "calandra", por_hora: 30) }.tap(&:save!)
  end

  def baixa(maquina)
    alvo = EstadoDasEtapas.call(pedido)["calandra"].keys.first
    post pedido_baixas_path(pedido), params: { etapa: "calandra", nivel: "linha", alvo: alvo, medida: "12,5", confirmar: "1", maquina: maquina.uuid }, as: :json
  end

  it "offers the stage's machines on its page and suggests one apart, then the last baixa's" do
    get producao_tecido_pedido_path(pedido, etapa: "calandra")
    expect(html.css("select.baixa-maquina").first.css("option").map(&:text)).to eq([ "Calandra 2", "Calandra 3" ])
    expect(html.css("[data-baixa-sugestao-value]").first["data-baixa-sugestao-value"]).to eq(maquina_pedido_baixas_path(pedido, etapa: "calandra"))

    get maquina_pedido_baixas_path(pedido, etapa: "calandra"), as: :json
    expect(response.parsed_body["origem"]).to eq("programada")
    baixa(rapida)
    get maquina_pedido_baixas_path(pedido, etapa: "calandra"), as: :json
    expect(response.parsed_body).to eq("maquina" => rapida.uuid, "nome" => "Calandra 3", "origem" => "baixa")
  end

  it "saves the machine and shows it on the line and in the history" do
    baixa(rapida)
    expect([ response.parsed_body, flash[:notice] ]).to eq([ { "ok" => true }, "Baixa de Calandra registrada (1 linha) na Calandra 3." ])
    get producao_tecido_pedido_path(pedido, etapa: "calandra")
    expect(html.at_css(".baixa-feita").text.squish).to include("✓ 12,50 m · Calandra 3 ·")
    expect(html.at_css("[data-baixa-maquina]").text).to eq("Calandra 3")
  end

  it "refuses a machine that doesn't do the stage, saving nothing" do
    epson = Maquina.new(nome: "Epson").tap { |m| m.trabalhos.build(trabalho: "impressao_dtf", por_hora: 10) }.tap(&:save!)
    baixa(epson)
    expect(response.parsed_body["error"]).to eq("Machine #{epson.uuid.inspect} doesn't do the Calandra; expected one of Calandra 2, Calandra 3")
    expect(pedido.baixas_producao.da_etapa("calandra")).to be_empty
  end

  it "moves the hold to the baixa's machine and says so, here and in the Histórico da programação" do
    MovimentoDaFila.create!(pedido: pedido, user: @usuario_logado, etapa: "calandra", setor: "estamparia", de_maquina: lenta, para_maquina: rapida)
    baixa(lenta)
    expect(flash[:notice]).to eq("Baixa de Calandra registrada (1 linha) na Calandra 2. Ela estava presa na Calandra 3: o resto fica na Calandra 2 até terminar.")
    get resumo_pedido_path(pedido)
    expect(html.css("[data-historico-programacao] li").last.text)
      .to include("começou a Calandra do ##{pedido.uuid.first(8)} na Calandra 2 (estava presa na Calandra 3) · pela baixa")
  end
end
