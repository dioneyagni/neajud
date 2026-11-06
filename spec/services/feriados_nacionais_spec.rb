require "rails_helper"

# Painel 2/4a (decided 05/11/2026, Q9a): the national holidays suggested,
# the movable ones from Easter.
RSpec.describe FeriadosNacionais do
  it "computes Easter Sunday" do
    expect([ 2024, 2025, 2026, 2027, 2038 ].map { |ano| described_class.pascoa(ano) })
      .to eq([ Date.new(2024, 3, 31), Date.new(2025, 4, 20), Date.new(2026, 4, 5), Date.new(2027, 3, 28), Date.new(2038, 4, 25) ])
  end

  it "lists 2026's holidays in order, the movable ones from Easter and Consciência Negra included" do
    feriados = described_class.do_ano(2026)
    expect(feriados.map(&:data)).to eq(feriados.map(&:data).sort)
    expect(feriados.to_h { |f| [ f.data.strftime("%d/%m"), f.nome ] }).to include(
      "16/02" => "Carnaval", "17/02" => "Carnaval", "03/04" => "Sexta-feira Santa", "04/06" => "Corpus Christi",
      "15/11" => "Proclamação da República", "20/11" => "Dia Nacional de Zumbi e da Consciência Negra", "25/12" => "Natal"
    )
    expect(feriados.size).to eq(13)
  end

  it "marks Carnaval and Corpus Christi as ponto facultativo" do
    expect(described_class.do_ano(2026).select(&:facultativo).map(&:nome)).to eq([ "Carnaval", "Carnaval", "Corpus Christi" ])
  end
end
