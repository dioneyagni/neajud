require "rails_helper"
require_relative "../support/producao_calcado"

# Painel 1/4 (decided 04/11/2026): the page, one row for the live update,
# a row's items and the delivery date — the Pedidos' permission and visibility.
RSpec.describe "Painel", type: :request do
  def entrar_como_cliente_final(cliente)
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user), client: cliente, funcao: funcao).user)
  end

  it "shows every pedido as a row in its block, the empty columns hidden" do
    pedido = pedido_calcado_confirmado
    rascunho = create(:pedido)
    get painel_path

    expect(response).to have_http_status(:ok)
    pagina = Nokogiri::HTML(response.body)
    expect(pagina.css(".painel-bloco-pedidos[data-bloco=prontos] .painel-pedido").map { |p| p["data-uuid"] }).to eq([ pedido.uuid ])
    expect(pagina.css(".painel-bloco-pedidos[data-bloco=pendentes] .painel-pedido").map { |p| p["data-uuid"] }).to eq([ rascunho.uuid ])
    expect(pagina.css(".painel-cab [data-coluna]").map(&:text)).to eq(%w[Arquivos Comercial Material Impressão Corte Estamparia Conferência Entrega])
    expect(pagina.css("#painel_#{pedido.uuid} [data-coluna=estamparia]").first["data-estado"]).to eq("travada")
  end

  it "answers one row in the columns asked, and nothing once it left the Painel" do
    pedido = pedido_calcado_confirmado
    get linha_do_painel_path(pedido.uuid), params: { colunas: %w[corte entrega] }
    linha = Nokogiri::HTML(response.body)
    expect(linha.css(".painel-pedido > .painel-linha [data-coluna]").map { |c| c["data-coluna"] }).to eq(%w[corte entrega])
    expect(linha.css(".painel-pedido").first["data-fora"].split).to eq(%w[arquivos comercial material impressao estamparia conferencia])

    pedido.excluir!(changed_by: "spec")
    get linha_do_painel_path(pedido.uuid)
    expect(response).to have_http_status(:no_content)
  end

  it "lists a pedido's items with their own Impressão lines" do
    pedido = pedido_calcado_confirmado(itens: 2)
    get itens_do_painel_path(pedido.uuid), params: { colunas: %w[impressao] }
    expect(Nokogiri::HTML(response.body).css(".painel-linha--item [data-coluna=impressao]").map { |c| c["data-estado"] }).to eq(%w[pode_comecar pode_comecar])
  end

  describe "a cliente final" do
    it "sees only his client's pedidos and none of the other's rows" do
      meu = pedido_calcado_confirmado
      outro = pedido_calcado_confirmado
      entrar_como_cliente_final(meu.client)

      get painel_path
      expect(response.body).to include(meu.uuid)
      expect(response.body).not_to include(outro.uuid)
      get linha_do_painel_path(outro.uuid)
      expect(response).to have_http_status(:no_content)
      get itens_do_painel_path(outro.uuid)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the delivery date" do
    let(:pedido) { pedido_calcado_confirmado }

    it "is set on a confirmed pedido and cleared when blank" do
      patch prazo_pedido_path(pedido), params: { prazo_entrega: "2026-11-20" }
      expect([ response, pedido.reload.prazo_entrega ]).to match([ redirect_to(resumo_pedido_path(pedido)), Date.new(2026, 11, 20) ])
      patch prazo_pedido_path(pedido), params: { prazo_entrega: "" }
      expect(pedido.reload.prazo_entrega).to be_nil
    end

    it "refuses what is not a date, saying the shape" do
      patch prazo_pedido_path(pedido), params: { prazo_entrega: "amanhã" }
      expect([ flash[:alert], pedido.reload.prazo_entrega ]).to eq([ %(Prazo "amanhã" is not a date; expected YYYY-MM-DD.), nil ])
    end

    # Only the factory promises a date to the client.
    it "is refused to a cliente final" do
      entrar_como_cliente_final(pedido.client)
      patch prazo_pedido_path(pedido), params: { prazo_entrega: "2026-11-20" }
      expect([ response.status, pedido.reload.prazo_entrega ]).to eq([ 403, nil ])
    end
  end
end
