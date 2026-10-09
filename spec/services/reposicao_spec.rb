require "rails_helper"

# Etapa 2.2 (4/4, decided 08-09/10/2026): a Conferência with fewer pieces
# than expected puts them in the pedido's open reposição — counted line by
# line, each with what to redo (Impressão, Corte) — which goes to production
# when the Conferência ends or by "Gerar reposição".
RSpec.describe "Reposição" do
  let(:lateral) { create(:peca, nome: "Lateral") }
  let(:lingua) { create(:peca, nome: "Língua") }
  let(:molde) { create(:molde, partes: [ lateral, lingua ]) }
  let(:pedido) { create(:pedido, status: "confirmado") }
  let(:usuario) { create(:user) }

  let!(:item) do
    cortes = [ lateral, lingua ].map do |peca|
      create(:arquivo, :corte, organized: true, peca: peca, client: molde.client, modelo: molde.modelo, giro: "180").tap do |c|
        c.moldes << molde
        create(:tamanho, arquivo: c, nome: "29-30", numeros: %w[29 30], position: 1)
      end
    end
    arte = create(:arquivo, molde: molde, client: molde.client, peca: lateral, tamanho: cortes.first.tamanhos.first)
    create(:arquivo, arte: arte.arte, molde: molde, client: molde.client, peca: lingua, tamanho: cortes.second.tamanhos.first)
    create(:item_pedido, pedido: pedido, arquivo: arte).tap do |i|
      i.compor_pecas!(MoldeComposicaoService.call(arte))
      i.grades.create!(tamanho_nome: "30", quantidade: 5)
    end
  end

  def baixa(etapa, medida:, nivel: "pedido", alvo: nil, contagens: nil, refazer: nil, confirmar: false, em: pedido)
    RegistrarBaixaService.call(em, etapa: etapa, nivel: nivel, alvo: alvo, medida: medida, contagens: contagens, refazer: refazer, confirmar: confirmar, user: usuario)
  end

  def ate_a_conferencia(em = pedido)
    %w[impressao corte estamparia].each { |etapa| baixa(etapa, medida: "20", confirmar: true, em: em) }
  end

  def linhas(em = pedido) = LinhasDeProducao.call(em, EtapasProducao.etapa("calcado", "conferencia"))

  before { ate_a_conferencia }

  it "asks a short group to count each line, then releases the reposição as the Conferência ends" do
    pedir = baixa("conferencia", medida: "18")
    expect([ pedir.estado, pedir.mensagem ]).to eq([ :contar, "Faltam 2 peças das 20 esperadas. Confira a contagem de cada linha e marque o que refazer: as peças que faltarem vão para a reposição." ])
    expect(pedir.linhas.map { |l| pedir.contagem.inicial(l) }).to eq([ 10, 10 ])

    lateral_30, lingua_30 = linhas.map(&:chave)
    feita = baixa("conferencia", medida: "18", contagens: { lateral_30 => "8", lingua_30 => "10" }).baixa
    expect([ feita.medida.to_i, feita.contagens ]).to eq([ 18, { lateral_30 => 8, lingua_30 => 10 } ])

    reposicao = feita.reposicao.reload
    expect(reposicao.attributes.values_at("status", "client_id", "reposicao_de_id")).to eq([ "confirmado", pedido.client_id, pedido.id ])
    expect(reposicao.itens_reposicao.map { |i| [ i.peca.nome, i.pecas, i.item_origem, i.refazer_impressao, i.refazer_corte ] }).to eq([ [ "Lateral", 2, item, true, true ] ])
  end

  it "keeps a line's shortage in the open reposição, adds the next one, and releases at the last line" do
    lateral_30, lingua_30 = linhas.map(&:chave)
    pedir = baixa("conferencia", nivel: "linha", alvo: lateral_30, medida: "9")
    expect([ pedir.estado, pedir.contagem.inicial(pedir.linhas.sole) ]).to eq([ :contar, 9 ])

    primeira = baixa("conferencia", nivel: "linha", alvo: lateral_30, medida: "9", contagens: { lateral_30 => "9" }).baixa
    expect(primeira.reposicao.status).to eq("rascunho")
    segunda = baixa("conferencia", nivel: "linha", alvo: lingua_30, medida: "7", contagens: { lingua_30 => "7" }).baixa
    expect(segunda.reposicao).to eq(primeira.reposicao)
    expect(primeira.reposicao.reload.attributes.values_at("status")).to eq([ "confirmado" ])
    expect(primeira.reposicao.itens_reposicao.map { |i| [ i.peca.nome, i.pecas ] }).to eq([ [ "Lateral", 1 ], [ "Língua", 3 ] ])
  end

  it "releases the open reposição early by Gerar reposição; a later shortage opens another" do
    lateral_30, lingua_30 = linhas.map(&:chave)
    aberta = baixa("conferencia", nivel: "linha", alvo: lateral_30, medida: "9", contagens: { lateral_30 => "9" }).baixa.reposicao
    expect(LiberarReposicaoService.call(pedido)).to eq(aberta)
    expect([ aberta.reload.status, pedido.reposicao_em_aberto ]).to eq([ "confirmado", nil ])
    outra = baixa("conferencia", nivel: "linha", alvo: lingua_30, medida: "9", contagens: { lingua_30 => "9" }).baixa.reposicao
    expect(outra).not_to eq(aberta)
  end

  # Decided 09/10/2026: the conferente unchecks what doesn't need redoing.
  it "prints and cuts again only what was left checked" do
    lateral_30, lingua_30 = linhas.map(&:chave)
    reposicao = baixa("conferencia", medida: "16", contagens: { lateral_30 => "8", lingua_30 => "8" },
                                       refazer: { lateral_30 => "impressao", lingua_30 => "corte" }).baixa.reposicao
    expect(reposicao.itens_reposicao.map { |i| [ i.peca.nome, i.refazer_impressao, i.refazer_corte ] }).to eq([ [ "Lateral", true, false ], [ "Língua", false, true ] ])
    expect(LinhasDeProducao.call(reposicao, EtapasProducao.etapa("calcado", "impressao")).map { |l| l.peca.nome }).to eq(%w[Lateral])
    expect(ProducaoPedidoService.call(reposicao).map { |l| l.peca.nome }).to eq(%w[Língua])
    expect(RegistrarBaixaService.situacao(reposicao, "estamparia").values.map { |s| [ s.linha.peca.nome, s.aguardando ] }).to eq([ %w[Lateral Impressão], %w[Língua Corte] ])
  end

  it "makes no reposição when the counts add up, and refuses a count that isn't a number" do
    expect(baixa("conferencia", medida: "18", contagens: { linhas.first.chave => "oito" }).mensagem).to eq('Count "oito" is not a number of pieces.')
    resultado = baixa("conferencia", medida: "20")
    expect([ resultado.estado, resultado.baixa.reposicao ]).to eq([ :ok, nil ])
  end

  describe "the reposição's own production" do
    let(:reposicao) do
      lateral_30, lingua_30 = linhas.map(&:chave)
      baixa("conferencia", medida: "17", contagens: { lateral_30 => "8", lingua_30 => "9" }).baixa.reposicao.reload
    end

    it "goes through every stage again, in pieces, for the missing ones only" do
      expect(ImpressaoPedidoService.call(reposicao).flat_map(&:linhas).map { |l| [ l.peca.nome, l.pecas ] }).to eq([ [ "Lateral", 2 ], [ "Língua", 1 ] ])
      expect(ProducaoPedidoService.call(reposicao).map { |l| [ l.peca.nome, l.pecas, l.por_lado ] }).to eq([ [ "Lateral", 2, nil ], [ "Língua", 1, nil ] ])
    end

    # Decided 08/10/2026: a reposição's own Conferência may make another one.
    it "makes its own reposição when its Conferência is short" do
      ate_a_conferencia(reposicao)
      chaves = linhas(reposicao).map(&:chave)
      outra = baixa("conferencia", medida: "2", em: reposicao, contagens: { chaves.first => "1", chaves.second => "1" }).baixa.reposicao
      expect([ outra.reposicao_de, outra.itens_reposicao.sum(:pecas) ]).to eq([ reposicao, 1 ])
    end

    it "warns the original's delivery while it isn't delivered" do
      codigo = reposicao.uuid.first(8)
      expect(EntregarPedidoService.call(pedido, user: usuario).mensagem).to eq("Ainda faltam: a reposição ##{codigo}. Entregar assim mesmo?")
      reposicao.update!(status: "entregue")
      expect(EntregarPedidoService.call(pedido, user: usuario).estado).to eq(:ok)
    end
  end
end
