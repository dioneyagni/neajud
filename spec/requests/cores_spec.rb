require "rails_helper"

# Etapa 2.5b (decided 12/10/2026): a cor lisa's page and "Cores".
RSpec.describe "Cores lisas", type: :request do
  let(:client) { create(:client) }
  let(:material) { MateriaPrima.find_or_create_by!(grupo_material: GrupoMaterial.find_or_create_by!(nome: "Oxford"), cor_material: CorMaterial.find_or_create_by!(nome: "Azul"), largura: "1.40", gramatura: "80g") }

  def cor(hex, client: nil, catalogo: true)
    arquivo = create(:arquivo, category: "artes", client: client, arte: Arte.new(tipo: "cor_lisa", no_catalogo: catalogo))
    l, a, b = MedidaDeCor.lab_do_hex(hex)
    arquivo.update!(approved_version: create(:arquivo_version, arquivo: arquivo, version_number: 1, status: :processed, lab_l: l, lab_a: a, lab_b: b, cor_hex: hex))
    arquivo.arte.batizar!([ l, a, b ])
    arquivo
  end

  def entrar_como_cliente_final
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user), client: client, funcao: funcao).user)
  end

  it "shows the color, its name and the near ones, practically equal or similar" do
    laranja = cor("#EF4123")
    cor("#EF4224")
    get arquivo_path(laranja)
    html = Nokogiri::HTML(response.body)
    expect(html.css("#cor-lisa-section .cor-lisa-nome").text).to eq("Laranja 1")
    expect(html.css(".cor-parecida--praticamente_igual").attr("data-codigo").value).to eq("Laranja 2")
  end

  it "sets the material, not in the name" do
    laranja = cor("#EF4123")
    patch material_arquivo_tipo_da_arte_path(laranja), params: { materia_prima_uuid: material.uuid }
    expect(laranja.arte.reload).to have_attributes(materia_prima: material, codigo: "Laranja 1")
  end

  it "lists every color in the chart and the table, by family and material" do
    cor("#EF4123").arte.update!(materia_prima: material)
    cor("#0071BB")
    get cores_path
    html = Nokogiri::HTML(response.body)
    expect(html.css(".cores-tabela tbody tr").map { |tr| tr["data-codigo"] }).to eq([ "Azul 1", "Laranja 1" ])
    expect(html.css(".cartela-celula:not(.cartela-celula--vazia)").size).to eq(2)
    get cores_path(familia: "Azul")
    expect(Nokogiri::HTML(response.body).css(".cores-tabela tbody tr").map { |tr| tr["data-codigo"] }).to eq([ "Azul 1" ])
    get cores_path(materia_prima_uuid: material.uuid)
    expect(Nokogiri::HTML(response.body).css(".cores-tabela tbody tr").map { |tr| tr["data-codigo"] }).to eq([ "Laranja 1" ])
  end

  it "marks a similar color on the gallery card without naming it" do
    cor("#EF4123")
    cor("#EF4224")
    get arquivos_path
    expect(Nokogiri::HTML(response.body).css(".stamp-card-parecida").size).to eq(2)
  end

  # Another client's color outside the catálogo is no business of his — not
  # even as "already in the system".
  it "a cliente final compares only with the colors he sees" do
    propria = cor("#EF4123", client: client, catalogo: false)
    cor("#EF4224", client: create(:client), catalogo: false)
    da_colecao = cor("#F04A2A")
    entrar_como_cliente_final
    get arquivo_path(propria)
    expect(Nokogiri::HTML(response.body).css(".cor-parecida").map { |li| li["data-codigo"] }).to eq([ da_colecao.arte.codigo ])
    get cores_path
    expect(Nokogiri::HTML(response.body).css(".cores-tabela tbody tr").map { |tr| tr["data-codigo"] }).to contain_exactly("Laranja 1", "Laranja 3")
  end
end
