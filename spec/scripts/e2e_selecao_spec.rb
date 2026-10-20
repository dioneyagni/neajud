require "rails_helper"
require "open3"
require Rails.root.join("lib/selecao_do_e2e")

# bin/e2e --alterados / --area (decided 19/10/2026): the specs a change needs,
# from e2e/areas.yml. Local only; CI runs the whole suite.
RSpec.describe SelecaoDoE2e do
  let(:ordem) { %w[autenticacao bloco-a bloco-b pedidos pedido-tecido producao-tecido lixeira] }
  let(:areas) do
    {
      "sempre" => %w[autenticacao],
      "bloco" => %w[bloco-a bloco-b],
      "sem_e2e" => [ "docs/**/*", "spec/**/*" ],
      "global" => [ "config/routes.rb", "app/views/layouts/**/*" ],
      "areas" => {
        "arquivos" => { "specs" => %w[bloco], "arquivos" => [ "app/controllers/arquivos_controller.rb" ] },
        "calcado" => { "specs" => %w[pedidos], "arquivos" => [ "app/views/pedidos/**/*" ] },
        "tecido" => { "specs" => %w[pedido-tecido producao-tecido], "arquivos" => [ "**/*tecido*", "**/*tecido*/**/*" ] },
        "lixeira" => { "specs" => %w[lixeira], "arquivos" => [ "app/views/lixeira/**/*" ] }
      }
    }
  end
  let(:selecao) { described_class.new(areas: areas, ordem: ordem) }

  it "runs an area's specs after autenticacao, in E2E_SPECS order, saying why" do
    resultado = selecao.dos_alterados([ "app/views/lixeira/index.html.erb", "app/views/pedidos/_item_tecido.html.erb" ])
    expect(resultado.specs).to eq(%w[autenticacao pedidos pedido-tecido producao-tecido lixeira])
    expect(resultado.motivos).to eq([ "app/views/lixeira/index.html.erb → lixeira", "app/views/pedidos/_item_tecido.html.erb → calcado, tecido" ])
  end

  it "matches a folder named after the area, like producao_tecido/" do
    expect(selecao.dos_alterados([ "app/views/producao_tecido/show.html.erb" ]).specs).to eq(%w[autenticacao pedido-tecido producao-tecido])
  end

  it "runs everything for a global file or one in no area: in doubt, run it all" do
    [ "config/routes.rb", "app/models/novidade.rb" ].each do |arquivo|
      resultado = selecao.dos_alterados([ "app/views/lixeira/index.html.erb", arquivo ])
      expect([ resultado.tudo, resultado.specs ]).to eq([ true, ordem ]), arquivo
    end
    expect(selecao.dos_alterados([ "app/models/novidade.rb" ]).motivos).to eq([ "app/models/novidade.rb → sem_area" ])
  end

  it "runs nothing for docs and RSpec only" do
    expect(selecao.dos_alterados([ "docs/plano.md", "spec/models/pedido_spec.rb" ]).specs).to be_empty
  end

  # The block's specs reuse each other's data: one of them is all of them.
  it "runs a changed spec, and a spec of the block brings the whole block" do
    expect(selecao.dos_alterados([ "e2e/lixeira.spec.js" ]).specs).to eq(%w[autenticacao lixeira])
    expect(selecao.dos_alterados([ "e2e/bloco-b.spec.js" ]).specs).to eq(%w[autenticacao bloco-a bloco-b])
    expect(selecao.dos_alterados([ "app/controllers/arquivos_controller.rb" ]).specs).to eq(%w[autenticacao bloco-a bloco-b])
  end

  it "picks an area by name and refuses an unknown one" do
    expect(selecao.da_area("tecido").specs).to eq(%w[autenticacao pedido-tecido producao-tecido])
    expect { selecao.da_area("tecid") }.to raise_error(described_class::Invalida, /unknown area "tecid"; expected one of arquivos, calcado, tecido, lixeira/)
  end

  it "refuses a spec in no area and an area naming a spec that doesn't exist" do
    expect { described_class.new(areas: areas, ordem: ordem + %w[novo]) }.to raise_error(described_class::Invalida, /specs in no area of e2e\/areas.yml: novo/)
    areas["areas"]["lixeira"]["specs"] << "sumiu"
    expect { selecao }.to raise_error(described_class::Invalida, /names specs not in E2E_SPECS: sumiu/)
  end

  # The real file must hold every spec bin/e2e lists.
  it "accepts e2e/areas.yml with bin/e2e's E2E_SPECS" do
    lista = File.read(Rails.root.join("bin/e2e"))[/^E2E_SPECS=\((.*?)^\)/m, 1].lines.reject { |l| l.strip.start_with?("#") }.join.split
    saida, status = Open3.capture2e(Rails.root.join("bin/e2e-selecao").to_s, "--area", "tecido", "--", *lista)
    expect(status).to be_success, saida
    expect(saida.lines.map(&:strip)).to include("autenticacao", "pedido-tecido", "precos-tecido", "producao-tecido", "cor-lisa")
  end
end
