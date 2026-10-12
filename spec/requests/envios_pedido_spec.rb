require "rails_helper"

# Etapa 2.8 (5/5, decided 12/10/2026): the cliente final builds his draft and
# sends it to the factory; he takes it back while it isn't confirmed; the
# team confirms it or returns it with a note.
RSpec.describe "A cliente final's draft", type: :request do
  let(:client) { create(:client) }
  let(:arte) { create(:arquivo, client: client, filename: "arte-bia") }
  let(:rascunho) { create(:pedido, client: client).tap { |p| create(:item_pedido, pedido: p, arquivo: arte).grades.create!(tamanho_nome: "_total", quantidade: 2) } }
  let(:item) { rascunho.itens_pedido.sole }

  def entrar_como_cliente_final
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user, nome: "Bia"), client: client, funcao: funcao).user)
  end

  it "sends it with pendências, showing the factory's as em análise" do
    entrar_como_cliente_final
    get resumo_pedido_path(rascunho)
    html = Nokogiri::HTML(response.body)
    # sem_preco is the factory's: he can't price a molde.
    expect(html.css(".pedido-pendencia--sem_preco .pedido-pendencia-em-analise").text).to eq("em análise")
    expect(html.css(".pedido-pendencia--sem_preco a")).to be_empty
    post enviar_pedido_path(rascunho)
    expect(response).to redirect_to(resumo_pedido_path(rascunho))
    expect(rascunho.reload.status).to eq("enviado")
  end

  # Regression: atualizar_item never checked the status — a confirmed
  # pedido's grade still changed.
  it "can't change it once sent, until he takes it back" do
    rascunho.update!(status: "enviado")
    entrar_como_cliente_final
    patch atualizar_item_pedido_path(rascunho), params: { id: item.uuid, grade: { "_total" => 5 } }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.parsed_body["error"]).to include("Retirar o envio")
    post retirar_envio_pedido_path(rascunho)
    patch atualizar_item_pedido_path(rascunho), params: { id: item.uuid, grade: { "_total" => 5 } }, as: :json
    expect(item.grades.sole.quantidade).to eq(5)
  end

  it "the team still changes a sent pedido, never a confirmed one" do
    rascunho.update!(status: "enviado")
    patch atualizar_item_pedido_path(rascunho), params: { id: item.uuid, grade: { "_total" => 4 } }, as: :json
    expect(item.grades.sole.quantidade).to eq(4)
    rascunho.update!(status: "confirmado")
    patch atualizar_item_pedido_path(rascunho), params: { id: item.uuid, grade: { "_total" => 9 } }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(item.grades.sole.quantidade).to eq(4)
  end

  it "the team returns it with a note, which he reads on top of his Pedidos and on the pedido" do
    rascunho.update!(status: "enviado")
    get pedidos_path
    expect(Nokogiri::HTML(response.body).css(".header-aguardando-fabrica").text).to eq("1")
    post devolver_pedido_path(rascunho), params: { recado: "Falta a língua 35" }
    expect(rascunho.reload.status).to eq("rascunho")
    entrar_como_cliente_final
    get pedidos_path
    expect(Nokogiri::HTML(response.body).css(".pedidos-devolvidos li[data-pedido='#{rascunho.uuid}'] blockquote").text).to eq("Falta a língua 35")
    get resumo_pedido_path(rascunho)
    expect(Nokogiri::HTML(response.body).css("#pedido-devolvido blockquote").text).to eq("Falta a língua 35")
  end

  it "the team confirms a sent pedido" do
    enviado = create(:pedido, client: client, status: "enviado").tap { |p| create(:item_pedido, :com_preco, pedido: p, arquivo: arte) }
    post confirmar_pedido_path(enviado)
    expect(enviado.reload.status).to eq("confirmado")
  end
end
