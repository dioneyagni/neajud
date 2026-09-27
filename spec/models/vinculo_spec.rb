require "rails_helper"

RSpec.describe Vinculo do
  it "links a user to the empresa only once" do
    vinculo = create(:vinculo)
    expect(build(:vinculo, user: vinculo.user, empresa: vinculo.empresa)).not_to be_valid
  end

  it "refuses a função that is in the trash" do
    funcao = create(:funcao).tap { |f| f.excluir!(changed_by: "10.0.0.1") }
    expect(build(:vinculo, funcao: funcao)).not_to be_valid
  end

  it "validates the shape of acessos_extras, naming what is wrong" do
    vinculo = build(:vinculo, acessos_extras: { "niveis" => { "pedidos" => 9, "cozinha" => 1 }, "acoes" => %w[voar] })
    expect(vinculo).not_to be_valid
    expect(vinculo.errors[:acessos_extras].join).to include('"cozinha"', "9 for pedidos", '"voar"')
  end

  it "#autorizacao combines the função with the extras" do
    vinculo = create(:vinculo, funcao: create(:funcao, niveis: { "pedidos" => 1 }), acessos_extras: { "niveis" => { "pedidos" => 2 } })
    expect(vinculo.autorizacao.nivel(:pedidos)).to eq(2)
  end
end
