require "rails_helper"

RSpec.describe FuncoesGradeService do
  let!(:dono) { create(:funcao_dono) }
  let!(:corte) { create(:funcao, nome: "Corte") }
  let!(:expedicao) { create(:funcao, nome: "Expedição") }

  it "saves names, levels (from select strings) and actions of every função" do
    erros = described_class.call(
      corte.uuid => { "nome" => "Corte e Costura", "niveis" => { "pedidos" => "1", "lixeira" => "2" }, "acoes" => [ "", "baixar_producao" ] },
      expedicao.uuid => { "nome" => "Expedição", "niveis" => { "pedidos" => "3" }, "acoes" => [ "" ] }
    )
    expect(erros).to eq([])
    expect(corte.reload).to have_attributes(nome: "Corte e Costura", niveis: { "pedidos" => 1, "lixeira" => 2 }, acoes: %w[baixar_producao])
    expect(expedicao.reload.niveis).to eq("pedidos" => 3)
  end

  it "saves nothing when one função is invalid, naming it" do
    erros = described_class.call(
      corte.uuid => { "nome" => "Corte", "niveis" => { "pedidos" => "2" } },
      expedicao.uuid => { "nome" => "", "niveis" => { "lixeira" => "3" } }
    )
    expect(erros.join).to include("Expedição:", "3 for lixeira")
    expect(corte.reload.niveis).to eq({})
  end

  it "ignores the Dono função" do
    described_class.call(dono.uuid => { "nome" => "Chefe", "niveis" => { "pedidos" => "0" } })
    expect(dono.reload.nome).to eq("Dono")
  end
end
