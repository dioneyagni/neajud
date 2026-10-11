require "rails_helper"

# Etapa 2.8 (1/5): who sees which records — the team everything, a cliente
# final only its client's.
RSpec.describe Visibilidade do
  let(:mks) { create(:client, name: "MKS") }
  let(:gms) { create(:client, name: "GMS") }
  let(:molde_mks) { create(:molde, client: mks) }
  let(:molde_gms) { create(:molde, client: gms) }

  it "shows the team every row" do
    [ molde_mks, molde_gms ]
    expect(described_class.new(nil).escopo(Molde)).to contain_exactly(molde_mks, molde_gms)
  end

  it "shows a cliente final its client's rows, through each model's path to it" do
    arte = create(:arquivo, client: mks, molde: molde_mks)
    create(:arquivo, client: gms, molde: molde_gms)
    corte = create(:arquivo, :corte).tap { |c| c.moldes << molde_mks }
    pedido = create(:pedido, client: mks)
    create(:pedido, client: gms)
    visivel = described_class.new(mks, abertos: TiposParaCliente::TIPOS)
    expect([ visivel.escopo(Client).to_a, visivel.escopo(Molde).to_a, visivel.escopo(Pedido).to_a ]).to eq([ [ mks ], [ molde_mks ], [ pedido ] ])
    expect(visivel.escopo(Arquivo)).to contain_exactly(arte, corte)
    expect(visivel.escopo(Arte)).to contain_exactly(arte.arte)
  end

  it "shows the common lists to everyone and the team's own records to no client" do
    peca = create(:peca)
    visivel = described_class.new(mks)
    expect([ visivel.escopo(Peca).to_a, visivel.escopo(User).to_a, visivel.escopo(Funcao).to_a ]).to eq([ [ peca ], [], [] ])
  end

  it "refuses a model without a rule, naming the ones that have one" do
    expect { described_class.new(nil).escopo(Ban) }.to raise_error(ArgumentError, /Ban has no visibility rule; expected one of .*Pedido/)
  end

  # Etapa 2.8 (3a): a kind the client's grid closes hides its records.
  describe "kinds closed by the client's grid" do
    it "hides each closed kind's models and keeps the others" do
      [ molde_mks, create(:pedido, client: mks) ]
      visivel = described_class.new(mks, abertos: %w[pedidos])
      expect([ visivel.escopo(Pedido).count, visivel.escopo(Molde).count, visivel.escopo(MovimentoEstoque).count ]).to eq([ 1, 0, 0 ])
    end

    it "leaves only the artes when the cortes are closed" do
      arte = create(:arquivo, client: mks, molde: molde_mks)
      corte = create(:arquivo, :corte).tap { |c| c.moldes << molde_mks }
      create(:tamanho, arquivo: corte)
      versoes = [ arte, corte ].map { |arquivo| create(:arquivo_version, arquivo: arquivo) }
      visivel = described_class.new(mks, abertos: [])
      expect([ visivel.escopo(Arquivo).to_a, visivel.escopo(Tamanho).to_a, visivel.escopo(ArquivoVersion).to_a ]).to eq([ [ arte ], [], [ versoes.first ] ])
    end

    it "reads the open kinds from the client's grid by default" do
      mks.update!(visibilidade: { "moldes" => false })
      expect(described_class.new(mks).escopo(Molde).to_a).to eq([])
    end

    it "tells which kinds are open, every one to the team, and refuses an unknown kind" do
      cliente = described_class.new(mks, abertos: %w[valores])
      expect([ cliente.aberto?(:valores), cliente.aberto?(:cortes), described_class.new(nil).aberto?(:cortes) ]).to eq([ true, false, true ])
      expect { cliente.aberto?(:custos) }.to raise_error(ArgumentError, /unknown kind "custos"; expected one of pedidos/)
    end
  end

  it "tells a cliente final from the team" do
    expect([ described_class.new(mks).cliente?, described_class.new(nil).cliente? ]).to eq([ true, false ])
  end
end
