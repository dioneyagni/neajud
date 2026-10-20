require "rails_helper"
require_relative "../support/tecidos"

# Etapa 2.3d1 (decided 19/10/2026): whose fabric a pedido takes cascades
# cliente → molde → pedido (blank inherits), chosen on the client's page, the
# molde's and the pedido's panel; the pedido's paper or DTF film is the
# empresa's default unless the team picks another. Confirming writes each
# item's owner.
RSpec.describe "A pedido's materials", type: :request do
  let(:client) { create(:client, name: "Calçados Sul") }
  let(:molde) { create(:molde, client: client, preco: 10) }
  let(:pedido) { create(:pedido, client: client) }
  let!(:item) do
    create(:item_pedido, pedido: pedido, arquivo: create(:arquivo, client: client)).tap do |i|
      i.arquivo.update_columns(molde_id: molde.id)
      i.grades.create!(tamanho_nome: "30", quantidade: 1)
    end
  end
  let(:papel) { criar_tecido(largura: "1,10 m", grupo: "Papel", cor: "Branco", tipo: "papel") }

  def resumo
    get resumo_pedido_path(pedido)
    html = Nokogiri::HTML(response.body)
    %w[dono-tecido material-impressao].map { |c| html.at_css("[data-resumo='#{c}']")&.text }
  end

  def entrar_como_cliente_final
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user), client: client, funcao: funcao).user)
  end

  it "shows what a calçado draft inherits and from which level, the client's page and the molde's setting it" do
    expect(resumo).to eq([ "Do cliente (padrão)", "1600 mm (sem material cadastrado)" ])
    patch client_path(client), params: { client: { dono_tecido: "empresa" } }
    expect(resumo.first).to eq("Da empresa (do cadastro do cliente)")
    patch molde_path(molde), params: { molde: { dono_tecido: "cliente" } }
    expect(resumo.first).to eq("Do cliente (do molde)")
    get molde_path(molde)
    expect(Nokogiri::HTML(response.body).at_css("#molde-dono-tecido option[selected]").text).to eq("Do cliente")
    patch molde_path(molde), params: { molde: { dono_tecido: "" } }
    expect(molde.reload.dono_tecido).to be_nil
  end

  it "the pedido's choice overrides, and a blank one inherits again; the paper is the team's" do
    patch materiais_pedido_path(pedido), params: { dono_tecido: "empresa", material_impressao_uuid: papel.uuid }
    expect(resumo).to eq([ "Da empresa (escolhido no pedido)", papel.nome_completo ])
    expect(pedido.reload.largura_do_papel_mm).to eq(1100)
    get resumo_pedido_path(pedido)
    opcoes = Nokogiri::HTML(response.body).css("#pedido-dono-tecido option").map(&:text)
    expect(opcoes).to eq([ "Herdar: do cliente (padrão)", "Do cliente", "Da empresa" ])
    patch materiais_pedido_path(pedido), params: { dono_tecido: "", material_impressao_uuid: "" }
    expect([ pedido.reload.dono_tecido, pedido.material_impressao ]).to eq([ nil, nil ])
  end

  it "refuses a material of another type and a pedido past its draft" do
    tecido = criar_tecido
    patch materiais_pedido_path(pedido), params: { material_impressao_uuid: tecido.uuid }
    expect(flash[:alert]).to include("is a tecido; a Calçado pedido prints on a papel")
    pedido.update_columns(status: "confirmado")
    patch materiais_pedido_path(pedido), params: { dono_tecido: "empresa" }
    expect([ pedido.reload.dono_tecido, flash[:alert] ]).to eq([ nil, "#{pedido.rotulo_lixeira} is confirmado; it changes only while editable" ])
  end

  # The cliente final knows whether he brings the fabric; the paper is production's.
  it "a cliente final sets whose fabric on his draft, never the paper" do
    entrar_como_cliente_final
    patch materiais_pedido_path(pedido), params: { dono_tecido: "empresa" }
    expect(pedido.reload.dono_tecido).to eq("empresa")
    patch materiais_pedido_path(pedido), params: { material_impressao_uuid: papel.uuid }
    expect([ pedido.reload.material_impressao, flash[:alert] ]).to eq([ nil, "The paper or film is the team's to choose" ])
    get resumo_pedido_path(pedido)
    expect(Nokogiri::HTML(response.body).css("#pedido-material-impressao")).to be_empty
  end

  it "confirming writes each item's owner, and a split copies the pedido's choices" do
    molde.update!(dono_tecido: "empresa")
    pedido.update!(material_impressao: papel)
    outro = create(:client)
    create(:item_pedido, :com_preco, pedido: pedido, arquivo: create(:arquivo, client: outro))
    post confirmar_pedido_path(pedido)
    expect(flash[:alert]).to be_nil
    novos = Pedido.where(status: "confirmado").order(:id)
    expect(novos.map(&:material_impressao)).to eq([ papel, papel ])
    expect(novos.flat_map { |p| p.itens_pedido.map(&:dono_tecido) }).to eq(%w[empresa cliente])
    molde.update!(dono_tecido: "cliente")
    expect(DonoDoTecido.do_item(novos.first.itens_pedido.first).dono).to eq("empresa")
  end

  it "a tecido pedido inherits the client's, which its charging follows, and is written on confirming" do
    Empresa.atual.update!(preco_impressao_metro_tecido: 15)
    oxford = criar_tecido.tap { |t| t.update!(preco_metro: 20) }
    cor = criar_obra_de_tecido("cor_lisa", client: client, no_catalogo: false, materia_prima: oxford)
    tecido = create(:pedido, tipo: "tecido", client: client)
    tecido_item = tecido.itens_pedido.create!(arquivo: cor.arquivos.first, materia_prima: oxford, metros: 2)
    expect(tecido_item.preco_tecido_efetivo).to be_nil
    client.update!(dono_tecido: "empresa")
    expect(tecido_item.reload.preco_tecido_efetivo).to eq(20)
    post confirmar_pedido_path(tecido)
    expect([ tecido.reload.status, tecido_item.reload.dono_tecido ]).to eq(%w[confirmado empresa])
  end
end
