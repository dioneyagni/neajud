require "rails_helper"

# Máquinas 1/5 (decided 20/11/2026): a machine, what it does and at what speed.
RSpec.describe Maquina do
  def maquina(nome = "Calandra 2", **trabalhos)
    described_class.new(nome: nome).tap do |m|
      trabalhos.each { |chave, por_hora| m.trabalhos.build(trabalho: chave.to_s, por_hora: por_hora) }
    end
  end

  it "does several trabalhos, each at its speed" do
    salva = maquina(calandra: 40, dublagem: 30).tap(&:save!)
    expect(salva.reload.trabalhos.map(&:descricao)).to eq([ "Calandra 40 m/h", "Dublagem 30 m/h" ])
    expect(salva.trabalho_de("dublagem").velocidade).to eq("30 m/h")
  end

  it "needs a name and at least one trabalho" do
    expect(maquina("").tap(&:valid?).errors.full_messages).to eq([ "Nome diga o nome da máquina", "Marque pelo menos um trabalho que a máquina faz." ])
  end

  it "refuses a speed of 0 or none, naming the trabalho" do
    expect(maquina(calandra: 0).tap(&:valid?).errors.full_messages).to eq([ "Calandra: Velocidade precisa ser mais que 0" ])
    expect(maquina(calandra: nil).tap(&:valid?).errors.full_messages).to eq([ "Calandra: Velocidade precisa ser mais que 0" ])
  end

  it "takes the Corte do calçado by its parameters, blank the default, 0 refused" do
    corte = maquina("Mesa 1").tap { |m| m.trabalhos.build(trabalho: "corte_calcado", velocidade_mm_s: 120) }
    expect(corte).to be_valid
    expect(corte.trabalhos.first.then { |t| [ t.parametro_do_corte(:velocidade_mm_s), t.parametro_do_corte(:pinca_s), t.velocidade ] })
      .to eq([ 120.0, 2.0, "faca 120 mm/s, os outros no padrão" ])
    corte.trabalhos.first.troca_min = 0
    expect(corte.tap(&:valid?).errors.full_messages).to eq([ "Corte do calçado: Troca de material (min) must be more than 0 (blank = the default)" ])
  end

  it "keeps its name unique, case and spaces aside, a trashed one saying to restore it" do
    antiga = maquina(calandra: 40).tap(&:save!)
    expect(maquina(" calandra 2 ", calandra: 40).tap(&:valid?).errors.full_messages).to eq([ 'Já existe a máquina "Calandra 2": escolha outro nome.' ])
    antiga.excluir!(changed_by: "127.0.0.1")
    expect(maquina(calandra: 40).tap(&:valid?).errors.full_messages.sole).to start_with('A máquina "Calandra 2" está na lixeira (desde ')
  end

  it "writes trash and restore in its histórico, and the Painel hears it" do
    salva = maquina(calandra: 40).tap(&:save!)
    expect(CanaisAoVivo).to receive(:avisar_fila).twice
    salva.excluir!(changed_by: "127.0.0.1")
    salva.restaurar!(changed_by: "127.0.0.1")
    expect(salva.alteracoes.recentes.map(&:texto)).to eq([ "restaurou", "mandou para a lixeira" ])
  end
end
