require "rails_helper"

# Primeiros passos 2/6a (decided 20/11 and 26/11/2026, canvas "Primeiros
# passos", 7–13): the first-run wizard right after the first access, a step
# at a time, each saved as answered; "Fazer depois" leaves a reminder on the
# Painel; redoing it shows what exists as done and only adds.
RSpec.describe "Assistente inicial", type: :request do
  def html = Nokogiri::HTML(response.body)
  def empresa = Empresa.atual.reload

  def salvar(passo, dados = {})
    patch passo_do_assistente_path(passo), params: { assistente: dados }
  end

  before { Funcao.criar_padrao! }

  describe "the first access", sem_login: true do
    it "goes to the wizard once the company and its dono exist" do
      Funcao.destroy_all
      post configuracao_path, params: { configuracao: { empresa_nome: "Fábrica X", nome: "Ana", email_address: "ana@x.com", password: "senha-segura-123" } }
      expect([ response, Empresa.atual.assistente_passo ]).to match([ redirect_to(assistente_path), "produz" ])
      follow_redirect!
      expect(response).to redirect_to(passo_do_assistente_path("produz"))
    end
  end

  it "walks the steps in order, the bar saying where it is, and ends on the Painel" do
    get passo_do_assistente_path("produz")
    expect([ html.css(".assistente-passos li").map { |li| li.text.squish }, html.at_css(".assistente-avancar")["value"] ])
      .to eq([ [ "1 O que produzem", "2 Quem trabalha", "3 Horário", "4 Máquinas", "5 Materiais" ], "Avançar" ])

    salvar("produz", tipos: %w[calcado dtf])
    expect([ response, empresa.tipos_produzidos, empresa.tecido_de ]).to match([ redirect_to(passo_do_assistente_path("quem")), %w[calcado dtf], nil ])
    get passo_do_assistente_path("materiais")
    expect(html.at_css(".assistente-avancar")["value"]).to eq("Concluir")
    salvar("materiais")
    expect([ response, empresa.assistente_concluido_em, empresa.assistente_passo ]).to match([ redirect_to(painel_path), be_present, nil ])
  end

  it "refuses no kind of work, and keeps whose fabric only with a fabric" do
    salvar("produz", tipos: [])
    expect([ response.status, html.at_css(".assistente-erros").text.squish ]).to eq([ 422, "Marque pelo menos uma coisa que vocês produzem" ])
    salvar("produz", tipos: %w[corrida], tecido_de: "cliente")
    expect([ empresa.tipos_produzidos, empresa.tecido_de ]).to eq([ %w[corrida], "cliente" ])
  end

  it "sends the funções unchecked to the trash and back, keeping one with people" do
    salvar("quem", funcoes: %w[Admin Designer], clientes_entram: "0")
    expect(Funcao.ativos.pluck(:nome)).to match_array(%w[Dono Admin Designer])
    create(:vinculo, user: create(:user), funcao: Funcao.find_by!(nome: "Designer"))
    salvar("quem", funcoes: %w[Admin Atendimento], clientes_entram: "1")
    expect([ Funcao.ativos.pluck(:nome), flash[:alert] ])
      .to match([ match_array([ "Dono", "Admin", "Atendimento", "Designer", "Cliente final" ]), "Designer tem pessoas e continua; tire as pessoas dela em Usuários antes" ])
  end

  it "proposes the turnos, creates them with the national holidays, and shows them done when redone" do
    get passo_do_assistente_path("horario")
    expect(html.css(".assistente-turno input[type=text]").map { |i| i["value"] }).to eq([ "Manhã", "Tarde", "" ])
    salvar("horario", turnos: [ { nome: "Manhã", inicio: "08:00", fim: "12:00", dias: %w[1 2 3 4 5] }, { nome: "", inicio: "", fim: "", dias: %w[1] } ], feriados: "1")
    expect(Turno.ativos.pluck(:nome, :dias)).to eq([ [ "Manhã", [ 1, 2, 3, 4, 5 ] ] ])
    expect(ExcecaoCalendario.where(origem: "feriado").count).to eq(FeriadosNacionais.do_ano(Date.current.year).count { |f| !f.facultativo })
    get passo_do_assistente_path("horario")
    expect([ html.css("[data-turno-feito]").map(&:text).map(&:squish), html.css(".assistente-turno").size ]).to eq([ [ "✓ Manhã · 08:00–12:00" ], 1 ])
  end

  it "says a turno that overlaps another, saving nothing of the step" do
    salvar("horario", turnos: [ { nome: "Manhã", inicio: "08:00", fim: "12:00", dias: %w[1] }, { nome: "Outra", inicio: "11:00", fim: "13:00", dias: %w[1] } ], feriados: "0")
    expect([ response.status, Turno.count, html.at_css(".assistente-erros").text ]).to match([ 422, 0, /Outra: .*overlaps Manhã/ ])
  end

  it "creates a machine per row, offering only the trabalhos of the kinds marked" do
    salvar("produz", tipos: %w[dtf])
    get passo_do_assistente_path("maquinas")
    expect(html.css("select[name='assistente[maquinas][][trabalho]']").first.css("option").map(&:text)).to eq([ "Impressão DTF", "Corte do DTF" ])
    salvar("maquinas", maquinas: [ { nome: "Epson F", trabalho: "impressao_dtf", por_hora: "40" }, { nome: "", trabalho: "corte_dtf", por_hora: "" } ])
    expect(Maquina.ativos.map { |m| [ m.nome, m.trabalhos.map(&:descricao) ] }).to eq([ [ "Epson F", [ "Impressão DTF 40 m/h" ] ] ])
  end

  it "registers the typical materials checked, with their groups, and the empresa's defaults" do
    salvar("produz", tipos: %w[calcado dtf])
    get passo_do_assistente_path("materiais")
    expect(html.css("[data-material]").map { |l| l["data-material"] }).to eq(%w[papel kraft plastico oxford_branco microfibra cetim filme_dtf])
    salvar("materiais", materiais: %w[papel filme_dtf oxford_branco])
    expect(MateriaPrima.includes(:grupo_material).map { |m| m.grupo_material.nome }).to match_array([ "Papel", "Filme DTF", "Oxford" ])
    expect([ empresa.papel_padrao.grupo_material.nome, empresa.filme_dtf_padrao.micras ]).to eq([ "Papel", 75 ])
    get passo_do_assistente_path("materiais")
    expect(html.css("[data-material] .assistente-feito").size).to eq(3)
  end

  # Found 26/11/2026 on a fresh instance: the network's groups were there
  # first, and one asking what a typical material doesn't have blocked the
  # whole step. It is left out, saying why; the DTF film has its own group.
  it "goes on past a group already there that refuses a material, saying which" do
    ImportarRedeDeDublagens.new.call
    GrupoMaterial.create!(nome: "Papel", superficie: false, base: false, estampavel: "nao").tap { |g| g.definir_atributos(pede: [], obrigatorios: %w[espessura_mm]) }.save!
    salvar("produz", tipos: %w[calcado dtf])
    salvar("materiais", materiais: %w[papel filme_dtf])
    expect([ response, flash[:alert] ]).to match([ redirect_to(painel_path), "Papel de sublimação Branco ficou de fora (Espessura (mm) é obrigatório no grupo Papel): cadastre em Materiais" ])
    expect([ empresa.filme_dtf_padrao.grupo_material.nome, empresa.papel_padrao ]).to eq([ "Filme DTF", nil ])
  end

  it "leaves a reminder on the Painel after Fazer depois, from the step he left, until it ends" do
    get passo_do_assistente_path("horario")
    expect(empresa.assistente_passo).to be_nil
    post assistente_depois_path(passo: "horario")
    follow_redirect!
    expect(html.at_css("[data-aviso-do-assistente]").text.squish).to include("Faltam 3 de 5 passos: Horário, Máquinas e Materiais")
    get assistente_path
    expect(response).to redirect_to(passo_do_assistente_path("horario"))
  end

  it "is the dono's only, and a step that doesn't exist is not found" do
    get passo_do_assistente_path("nada")
    expect(response).to have_http_status(:not_found)
    entrar_com_funcao(niveis: Autorizacao::AREAS.index_with { |a| Autorizacao.nivel_maximo(a) }, acoes: Autorizacao::ACOES)
    get assistente_path
    expect(response).to have_http_status(:forbidden)
  end
end
