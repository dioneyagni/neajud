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
    visivel = described_class.new(mks)
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

  it "tells a cliente final from the team" do
    expect([ described_class.new(mks).cliente?, described_class.new(nil).cliente? ]).to eq([ true, false ])
  end
end
