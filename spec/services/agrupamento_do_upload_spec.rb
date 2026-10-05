require "rails_helper"

# Etapa 1.2 (2/3, parte 3): the dev data's real file names (05/10/2026).
RSpec.describe AgrupamentoDoUpload do
  let!(:lateral) { create(:peca, nome: "Lateral") }
  let!(:lingua) { create(:peca, nome: "Língua") }
  let(:mb) { 1_048_576 }

  def agrupar(*arquivos) = described_class.call(arquivos.map { |nome, bytes| { nome: nome, bytes: bytes || mb } })

  def linhas(grupo) = grupo.arquivos.map { |a| [ a.nome, a.parte&.nome, a.tamanho, a.piloto ] }

  it "groups one arte's files, reading each one's part and size, and suggests the heavy one as piloto" do
    resultado = agrupar([ "20-BLUEY AZUL.tif", 78 * mb ], [ "20-bluey azul-LATERAL-23_24.tif", 5 * mb ],
                        [ "20-bluey azul-LATERAL-25_26.tif", 5 * mb ], [ "20-BLUEY AZUL-LINGUA.tif", 5 * mb ])
    expect(resultado[:conferir]).to be true
    expect(resultado[:grupos].size).to eq(1)
    grupo = resultado[:grupos].first
    expect(grupo.titulo).to eq("20 · BLUEY AZUL")
    expect(linhas(grupo)).to eq([
      [ "20-BLUEY AZUL.tif", nil, nil, false ],
      [ "20-bluey azul-LATERAL-23_24.tif", "Lateral", "23-24", false ],
      [ "20-bluey azul-LATERAL-25_26.tif", "Lateral", "25-26", false ],
      [ "20-BLUEY AZUL-LINGUA.tif", "Língua", nil, false ]
    ])
  end

  it "suggests the piloto per part: 3 times the median weight of the others, or an editable format" do
    grupo = agrupar([ "20-x-LATERAL.tif", 78 * mb ], [ "20-x-LATERAL-23_24.tif", 5 * mb ], [ "20-x-LATERAL-25_26.tif", 5 * mb ],
                    [ "20-x-LINGUA.psd", 3 * mb ], [ "20-x-LINGUA-23_24.tif", 5 * mb ])[:grupos].first
    expect(grupo.arquivos.select(&:piloto).map(&:nome)).to eq([ "20-x-LATERAL.tif", "20-x-LINGUA.psd" ])
  end

  it "doesn't suggest a piloto below 3 times the median, nor in a part with one file" do
    grupo = agrupar([ "20-x-LATERAL-23_24.tif", 14 * mb ], [ "20-x-LATERAL-25_26.tif", 5 * mb ], [ "20-x-LINGUA.tif", 80 * mb ])[:grupos].first
    expect(grupo.arquivos.select(&:piloto)).to be_empty
  end

  # Decided 02/10/2026: the leading number is the referência.
  it "keeps different referências apart, and the DTF numbering too (joined by hand)" do
    grupos = agrupar([ "20-BLUEY AZUL.tif" ], [ "41-BLUEY AZUL.tif" ], [ "863-ARCOVERDE - P - 1,9 X 1,3 NEW.tif" ], [ "864-ARCOVERDE - M - 2,2 X 1,6 NEW.tif" ])
    expect(grupos[:grupos].map(&:titulo)).to eq([ "20 · BLUEY AZUL", "41 · BLUEY AZUL", "863 · ARCOVERDE", "864 · ARCOVERDE" ])
    expect(grupos[:conferir]).to be false
  end

  it "leaves cortes and names without a nome alone" do
    grupos = agrupar([ "29-30.dxf" ], [ "29-30.tif" ], [ "36 ao 48.dxf" ])[:grupos]
    expect(grupos.map { |g| g.arquivos.size }).to eq([ 1, 1, 1 ])
  end

  it "points out existing artes with the same referência and nome, stored or read from the file name" do
    molde = create(:molde)
    com_molde = create(:arquivo, filename: "qualquer", molde: molde, referencia: Referencia.do_molde!(molde, "20"), nome: "Bluey Azul")
    sem_molde = create(:arquivo, filename: "20-BLUEY AZUL-LINGUA")
    create(:arquivo, filename: "41-BLUEY AZUL")
    grupo = agrupar([ "20-bluey azul-LATERAL-23_24.tif" ], [ "20-bluey azul-LATERAL-25_26.tif" ])[:grupos].first
    expect(grupo.existentes).to contain_exactly(com_molde, sem_molde)
  end
end
