require "rails_helper"
require_relative "../support/construcoes"

# Rede editável 2/2b (decided 10/11/2026): adding and renaming a situação,
# with its histórico (Q2a); a rename renames the construções not in use
# (Q1b) and leaves the ones in use as they are.
RSpec.describe SalvarSituacao do
  let(:user) { create(:user) }
  let(:salvar) { ->(situacao, nome) { described_class.new(situacao, nome, construcoes: Construcao.all, user: user).call } }

  it "adds one with a 'criou' line" do
    situacao = SituacaoDublagem.new
    expect(salvar.(situacao, "Tecido úmido")).to be(true)
    expect([ situacao.chave, situacao.alteracoes.sole.texto, situacao.alteracoes.sole.user ]).to eq([ "tecido_umido", "criou Tecido úmido", user ])
    expect(RedeDeDublagens.situacoes).to include("tecido_umido" => "Tecido úmido")
  end

  it "refuses a repeated or blank name, writing nothing" do
    importar_rede_de_dublagens
    expect(salvar.(SituacaoDublagem.new, "tecido molha")).to be(false)
    expect(salvar.(SituacaoDublagem.new, "  ")).to be(false)
    expect(AlteracaoDaRede.count).to eq(0)
  end

  it "renames the construções not in use and keeps the ones in use" do
    oxford = material_de_dublagem("Oxford")
    lona = material_de_dublagem("Lona")
    filme = material_de_dublagem("Filme", tipo: "filme", micras: 35)
    sem_uso = montar_construcao([ oxford, "trama" ], [ lona, filme ], situacao: "vai_frequencia").tap(&:save!)
    em_uso = montar_construcao([ oxford, "avesso" ], [ lona, filme ], situacao: "vai_frequencia").tap(&:save!)
    MovimentoEstoque.create!(materia_prima: em_uso.materia_prima, tipo: "entrada", quantidade: 5, da_empresa: true)
    nome_em_uso = em_uso.nome
    situacao = SituacaoDublagem.find_by!(chave: "vai_frequencia")

    expect(salvar.(situacao, "Frequência alta")).to be(true)
    expect(sem_uso.reload.nome).to end_with("(Frequência alta)")
    expect(sem_uso.materia_prima.reload.nome_completo).to end_with("(Frequência alta)")
    expect(em_uso.reload.nome).to eq(nome_em_uso)
    expect(situacao.alteracoes.sole.texto).to eq("renomeou Vai frequência → Frequência alta; 1 construção renomeada")
  end

  it "writes no line when the name did not change" do
    importar_rede_de_dublagens
    situacao = SituacaoDublagem.find_by!(chave: "tecido_molha")
    expect(salvar.(situacao, " Tecido molha ")).to be(true)
    expect(situacao.alteracoes).to be_empty
  end
end
