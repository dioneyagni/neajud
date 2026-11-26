require "rails_helper"

# Primeiros passos 1/6 (decided 26/11/2026, Q8a): config/mapa.yml is the
# single source of the parts, their links and their empty screens; what
# would break quietly later is refused when it is read.
RSpec.describe MapaDoSistema do
  let(:todos) { ->(modelo) { modelo.all } }

  def mapa(**mudancas)
    conteudo = YAML.safe_load_file(MapaDoSistema::ARQUIVO)
    mudancas.each { |id, dados| conteudo["partes"][id.to_s] = conteudo["partes"][id.to_s].merge(dados.deep_stringify_keys) }
    LeitorDoMapa.new(conteudo).call
  end

  it "reads the map's 29 parts in 7 blocks, every link to a part that exists" do
    partes = described_class.partes
    expect([ partes.size, described_class.blocos.size ]).to eq([ 29, 7 ])
    expect(partes.values.flat_map { |p| p.precisa + p.alimenta } - partes.keys).to eq([])
    expect(described_class.parte(:pedido).then { |p| [ p.precisa, p.vazio.acao.tipo, p.vazio.falta ] })
      .to eq([ %w[cliente arte molde material], "post", %w[clientes artes moldes materiais] ])
  end

  it "has a counter for every contagem, and no counter left unused" do
    expect(described_class.contagens.keys.sort).to eq(described_class::CONTADORES.keys.sort)
  end

  it "refuses, all at once, a link to no part, a page or an action with no route, an unknown kind and an unknown contagem" do
    expect do
      mapa(cliente: { precisa: [ "fantasma" ], pagina: "nao_existe" },
           peca: { vazio: { titulo: "x", texto: "y", acao: { rotulo: "z", tipo: "telepatia" }, falta: [ "nada" ] } },
           maquinas: { vazio: { titulo: "x", texto: "y", acao: { rotulo: "z", tipo: "link", alvo: "sem_rota" } } })
    end.to raise_error(MapaDoSistema::Invalido, a_string_including(
      'cliente: links to "fantasma", not a part', 'cliente: page "nao_existe" has no route',
      'peca: falta "nada" is not a contagem', 'peca: action kind "telepatia" is not one of link, post, dialogo, ancora',
      'maquinas: action target "sem_rota" has no route'))
  end

  it "says an unknown part's name and the ones expected" do
    expect { described_class.parte(:fantasma) }.to raise_error(MapaDoSistema::Invalido, /unknown part :fantasma of the map; expected one of empresa, funcoes/)
  end

  describe ".falta" do
    it "counts what comes before through the scope given: none, then some" do
      expect(described_class.falta(:pedido, visiveis: todos).map { |f| [ f.contagem.id, f.ok, f.texto ] }.first(2))
        .to eq([ [ "clientes", false, "nenhum ainda" ], [ "artes", false, "nenhuma ainda" ] ])
      create(:client)
      create(:client)
      expect(described_class.falta(:pedido, visiveis: todos).first.then { |f| [ f.ok, f.texto, f.parte.id ] }).to eq([ true, "2 cadastrados", "cliente" ])
    end

    it "counts only what the scope lets through" do
      create(:client)
      expect(described_class.falta(:molde, visiveis: ->(modelo) { modelo.none }).sole.texto).to eq("nenhum ainda")
    end

    it "takes the rhythms as done only when every stage has one" do
      RitmoProducao.create!(tipo: "calcado", etapa: "impressao", por_hora: 10)
      ritmos = described_class.falta(:painel, visiveis: todos).find { |f| f.contagem.id == "ritmos" }
      expect([ ritmos.ok, ritmos.texto ]).to match([ false, /\A2 de \d+ etapas\z/ ])
    end

    it "has nothing before a part without a falta" do
      expect(described_class.falta(:cliente, visiveis: todos)).to eq([])
    end
  end
end
