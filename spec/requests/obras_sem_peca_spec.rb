require "rails_helper"

# Etapa 2.5c (decided 12/10/2026): a work without corte has no part, side,
# piloto or paper consumption on its page, its card and the upload's
# conference — a DTF keeps its sizes; a corrida or a cor lisa, sold by the
# meter at a fixed price, has none.
RSpec.describe "A work without corte, without parts", type: :request do
  def arquivo_medido(arte, nome)
    arquivo = create(:arquivo, category: "artes", filename: nome, tamanho_rotulo: "P", arte: arte)
    version = create(:arquivo_version, arquivo: arquivo)
    ArquivoImageMetadata.create!(arquivo_version: version, width_px: 3000, height_px: 600, dpi: 300)
    arquivo.update!(approved_version: version)
    arquivo
  end

  def lista_da_arte(arquivo)
    get arquivo_path(arquivo)
    Nokogiri::HTML(response.body).at_css("#arte-arquivos")
  end

  it "a DTF lists its sizes, without part heading, consumption or piloto" do
    arte = Arte.novo_do_tipo("dtf").tap(&:save!)
    arquivo = arquivo_medido(arte, "863-arcoverde-p")
    arquivo_medido(arte, "863-arcoverde-m")
    lista = lista_da_arte(arquivo)
    expect(lista.css(".arte-arquivo-tamanho").map(&:text)).to eq([ "P", "P" ])
    # No parts, no paper per piece (the film's layout is 2.6's), no piloto: each file is the editable one.
    expect(lista.css("h4, .arte-arquivo-consumo, .arte-tornar-piloto, .arte-lado, select[name=peca_uuid], select[name=lado]")).to be_empty
    expect(lista.at_css("input[name=tamanho_rotulo]")).to be_present
  end

  it "a corrida lists its files without a size either" do
    arte = Arte.novo_do_tipo("corrida").tap(&:save!)
    arquivo = arquivo_medido(arte, "cr-floral")
    arquivo_medido(arte, "cr-floral-b")
    lista = lista_da_arte(arquivo)
    # Sold by the meter: no size, no part, no consumption.
    expect(lista.css(".arte-arquivo-tamanho, .arte-arquivo-consumo, h4, input[name=tamanho_rotulo]")).to be_empty
    get arquivos_path
    expect(Nokogiri::HTML(response.body).at_css("##{CanaisAoVivo.id_do_cartao(arquivo)} .stamp-card-arte").text).to eq("2 files")
  end

  it "a calçado arte keeps its parts, consumption and piloto" do
    arquivo = arquivo_medido(Arte.create!, "tenis-lateral")
    arquivo_medido(arquivo.arte, "tenis-lateral-b")
    lista = lista_da_arte(arquivo)
    expect(lista.css("h4").map(&:text)).to eq([ "Part not known yet" ])
    expect(lista.css(".arte-arquivo-consumo, .arte-tornar-piloto").size).to eq(4)
  end

  it "the card of a DTF sums up its sizes alone" do
    arte = Arte.novo_do_tipo("dtf").tap(&:save!)
    # Numeric sizes: the P/M/G order comes with the DTF's grade (2.6).
    arquivo = create(:arquivo, category: "artes", tamanho_rotulo: "10", arte: arte)
    create(:arquivo, category: "artes", tamanho_rotulo: "12", arte: arte)
    get arquivos_path
    expect(Nokogiri::HTML(response.body).at_css("##{CanaisAoVivo.id_do_cartao(arquivo)} .stamp-card-arte").text).to eq("2 files · 10, 12")
  end

  it "refuses making a file of a DTF the piloto" do
    arquivo = create(:arquivo, category: "artes", arte: Arte.novo_do_tipo("dtf"))
    post tornar_piloto_arquivo_arte_path(arquivo)
    expect(flash[:alert]).to include("Etiqueta DTF has no piloto")
    expect(arquivo.reload.papel).to eq("producao")
  end

  it "the conference learns which fields each kind has" do
    post agrupamento_arquivos_path, params: { arquivos: [ { nome: "863-ARCOVERDE-P.tif", bytes: 10 } ] }, as: :json
    expect(response.parsed_body["tipos"].map { |t| t.values_at("tipo", "usa_pecas", "usa_tamanhos") })
      .to eq([ [ "calcado", true, true ], [ "dtf", false, true ], [ "corrida", false, false ], [ "cor_lisa", false, false ] ])
  end
end
