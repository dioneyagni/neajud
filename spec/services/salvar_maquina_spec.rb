require "rails_helper"

# Máquinas 1/5: the machine's page saves the name and what it does, and its
# histórico says what changed.
RSpec.describe SalvarMaquina do
  let(:user) { create(:user) }

  def salvar(maquina, nome: "Calandra 2", **trabalhos)
    described_class.new(maquina, { nome: nome, trabalhos: trabalhos }, user: user).call
  end

  it "creates it with the checked trabalhos only, the numbers as typed in Brazil" do
    maquina = Maquina.new
    expect(salvar(maquina, calandra: { marcado: "1", por_hora: "40,5" }, dublagem: { marcado: "0", por_hora: "30" })).to be(true)
    expect(maquina.reload.trabalhos.map { |t| [ t.trabalho, t.por_hora ] }).to eq([ [ "calandra", 40.5 ] ])
    expect(maquina.alteracoes.map { |a| [ a.texto, a.user ] }).to eq([ [ "criou com Calandra 40,5 m/h", user ] ])
  end

  it "says what was added, removed, sped up and renamed; nothing changed, no line" do
    maquina = Maquina.new.tap { |m| salvar(m, calandra: { marcado: "1", por_hora: "40" }, estamparia: { marcado: "1", por_hora: "50" }) }
    salvar(maquina, nome: "Calandra 3", calandra: { marcado: "1", por_hora: "45" }, dublagem: { marcado: "1", por_hora: "30" })
    expect(maquina.alteracoes.recentes.first.texto).to eq("renomeou Calandra 2 → Calandra 3; tirou Estamparia; Calandra 40 m/h → 45 m/h; acrescentou Dublagem 30 m/h")
    expect { salvar(maquina, nome: "Calandra 3", calandra: { marcado: "1", por_hora: "45" }, dublagem: { marcado: "1", por_hora: "30" }) }
      .not_to(change { maquina.alteracoes.count })
    expect(maquina.reload.trabalhos.map(&:trabalho)).to eq(%w[calandra dublagem])
  end

  it "keeps only the Corte do calçado's parameters, never a speed" do
    maquina = Maquina.new
    salvar(maquina, nome: "Mesa 1", corte_calcado: { marcado: "1", por_hora: "9", velocidade_mm_s: "120", pinca_s: "" })
    expect(maquina.reload.trabalhos.sole.then { |t| [ t.por_hora, t.velocidade_mm_s, t.pinca_s ] }).to eq([ nil, 120, nil ])
    expect(maquina.alteracoes.sole.texto).to eq("criou com Corte do calçado (faca 120 mm/s, os outros no padrão)")
  end

  it "writes nothing when refused" do
    maquina = Maquina.new
    expect(salvar(maquina, calandra: { marcado: "1", por_hora: "" })).to be(false)
    expect([ Maquina.count, maquina.errors.full_messages ]).to eq([ 0, [ "Calandra: Velocidade precisa ser mais que 0" ] ])
  end
end
