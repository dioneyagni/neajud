require "rails_helper"

# Primeiros passos 2/6a: the wizard's steps are a list (how many isn't
# fixed, 26/11/2026), and what each shows is config/assistente.yml.
RSpec.describe PassosDoAssistente do
  it "walks the list: place, next, previous and how many are left" do
    expect([ described_class.posicao("horario"), described_class.seguinte("horario").chave, described_class.anterior("horario").chave, described_class.faltam("horario") ])
      .to eq([ 3, "maquinas", "quem", 3 ])
    expect([ described_class.anterior("produz"), described_class.seguinte("materiais") ]).to eq([ nil, nil ])
  end

  it "names a step that doesn't exist and the ones expected" do
    expect { described_class.passo("pintura") }.to raise_error(described_class::Desconhecido, /"pintura" is not a step of the wizard; expected one of produz, quem/)
  end

  it "has a view for every step" do
    expect(described_class.todos.reject { |passo| Rails.root.join("app/views/assistente/_passo_#{passo.chave}.html.erb").exist? }).to eq([])
  end
end

RSpec.describe ConteudoDoAssistente do
  it "gives the typical materials and trabalhos of the kinds marked, each once" do
    expect(described_class.materiais_de(%w[corrida cor_lisa]).keys).to eq(%w[papel oxford_branco microfibra cetim telinha tnt])
    expect([ described_class.trabalhos_de(%w[corrida dublagem]), described_class.trabalhos_de(nil) ]).to eq([ %w[impressao_papel calandra dublagem], TrabalhosDeMaquina.chaves ])
  end

  it "refuses a kind naming a trabalho or a material that doesn't exist" do
    dados = YAML.safe_load_file(described_class::ARQUIVO)
    dados["tipos"]["dtf"]["trabalhos"] << "teleporte"
    dados["tipos"]["dtf"]["materiais"] << "ouro"
    allow(described_class).to receive(:dados).and_return(dados)
    described_class.instance_variable_set(:@tipos, nil)
    expect { described_class.tipos }.to raise_error(described_class::Invalido, /dtf: trabalho "teleporte" is not one of .*; dtf: material "ouro" is not in materiais/)
  ensure
    described_class.instance_variable_set(:@tipos, nil)
  end
end
