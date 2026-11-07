require "rails_helper"
require_relative "../support/producao_calcado"
require_relative "../support/fila_de_producao"

# Painel 1/4 (decided 04/11/2026): the page, a row's items and the delivery
# date — the Pedidos' permission and visibility. Painel 2/4b: the blocks in
# time, the previsão and each sector's queue; a cliente final by day only.
RSpec.describe "Painel", type: :request do
  def entrar_como_cliente_final(cliente)
    funcao = create(:funcao, :para_cliente, niveis: Autorizacao::NIVEL_MAXIMO_PARA_CLIENTE)
    entrar_como(create(:vinculo, user: create(:user), client: cliente, funcao: funcao).user)
  end

  it "shows every pedido as a row in its block in time, the empty columns hidden" do
    pedido = pedido_calcado_confirmado
    rascunho = create(:pedido)
    get painel_path

    expect(response).to have_http_status(:ok)
    pagina = Nokogiri::HTML(response.body)
    # No rhythm (nor turnos) yet: no previsão.
    expect(pagina.css(".painel-bloco-pedidos[data-bloco=sem_previsao] .painel-pedido").map { |p| p["data-uuid"] }).to eq([ pedido.uuid ])
    expect(pagina.css(".painel-bloco-pedidos[data-bloco=pendentes] .painel-pedido").map { |p| p["data-uuid"] }).to eq([ rascunho.uuid ])
    expect(pagina.css(".painel-cab [data-coluna]").map(&:text)).to eq(%w[Arquivos Comercial Material Impressão Corte Estamparia Conferência Entrega])
    expect(pagina.css("#painel_#{pedido.uuid} [data-coluna=estamparia]").first["data-estado"]).to eq("travada")
    expect(pagina.css("#painel_#{pedido.uuid} [data-previsao]").sole.text).to eq("Impressão (Calçado) sem ritmo")
  end

  # Q3a, Q6a: the row goes to Agora, with its previsão and folga; the
  # sector's tab is its numbered queue (the Fila A mockup).
  it "puts a pedido in Agora with its previsão, folga and place in each sector's queue" do
    turno_o_dia_todo
    ritmos_do_calcado
    pedido = pedido_calcado_confirmado
    pedido.update!(prazo_entrega: Date.current + 3)
    get painel_path

    pagina = Nokogiri::HTML(response.body)
    linha = pagina.css(".painel-bloco-pedidos[data-bloco=agora] > .painel-pedido").sole
    expect([ linha["data-uuid"], linha["data-vai-atrasar"], linha.css(".painel-fim .painel-folga").text ]).to eq([ pedido.uuid, "false", "folga 3 dias" ])
    expect(linha.css("[data-previsao]").text).to start_with("hoje")
    expect(linha.css(".painel-faixa [data-etapa=impressao] .painel-no-tempo").text).to start_with("hoje")
    fila = pagina.css("[data-fila-setor=impressao]").sole
    expect(fila.css(".painel-fila-dia--hoje .painel-fila-dia-rel").text).to eq("hoje")
    expect(fila.css("[data-fila-pedido='#{pedido.uuid}'] .painel-fila-pos").map(&:text)).to eq([ "1º" ])
    expect(pagina.css("[data-fila-setor]").map { |s| s["data-fila-setor"] }).to eq(%w[impressao corte estamparia conferencia])
  end

  # Decided 05/11/2026: the reposição comes inside its original's row.
  it "shows a reposição under its original" do
    pedido = pedido_calcado_confirmado
    reposicao = reposicao_com_falta(pedido)
    get painel_path
    pagina = Nokogiri::HTML(response.body)
    expect(pagina.css("[data-painel-target=bloco] > .painel-pedido").map { |p| p["data-uuid"] }).to eq([ pedido.uuid ])
    filha = pagina.css("#painel_#{pedido.uuid} > .painel-reposicoes > .painel-pedido--reposicao").sole
    expect(filha["data-uuid"]).to eq(reposicao.uuid)
    expect(filha.css(".painel-ref--reposicao").text.squish).to eq("↻ reposição de ##{pedido.uuid.first(8)} · 2 peças")
    expect(pagina.css("#painel_#{pedido.uuid} > .painel-linha [data-coluna=entrega]").sole["data-estado"]).to eq("travada")
    expect(pagina.css("#painel_#{pedido.uuid} > .painel-faixa [data-percentuais]").sole.text.squish).to eq("(pedido 100% · reposição 0%)")
  end

  it "lists a pedido's items with their own Impressão lines" do
    pedido = pedido_calcado_confirmado(itens: 2)
    get itens_do_painel_path(pedido.uuid), params: { colunas: %w[impressao] }
    expect(Nokogiri::HTML(response.body).css(".painel-linha--item [data-coluna=impressao]").map { |c| c["data-estado"] }).to eq(%w[pode_comecar pode_comecar])
  end

  # Painel 2/4c (Q3a, Q6a): the second view, its window and order in the address.
  describe "the Linha do tempo" do
    def pagina(params = {})
      get painel_path(params)
      Nokogiri::HTML(response.body)
    end

    it "shows the view asked for, each pedido a bar, and each sector's load" do
      turno_o_dia_todo
      ritmos_do_calcado
      pedido = pedido_calcado_confirmado
      html = pagina(visao: "tempo")

      expect([ html.css("[data-painel-target=etapas]").sole.key?("hidden"), html.css("[data-painel-target=tempo]").sole.key?("hidden") ]).to eq([ true, false ])
      barra = html.css("[data-tempo-grupo=em_producao] #tempo_#{pedido.uuid}").sole
      expect([ barra["data-bloco"], barra.css("[data-tempo-seg]").map { |s| s["data-tempo-seg"] } ]).to eq([ "agora", %w[feito previsto] ])
      expect(barra.css(".painel-faixa .painel-tdp [data-tdp-raia]").map { |r| r["data-tdp-raia"] }).to eq(%w[impressao corte estamparia conferencia])
      expect(html.css("[data-tempo-carga]").map { |c| c["data-tempo-carga"] }).to eq(%w[impressao corte estamparia conferencia])
      expect(html.css("[data-tempo-dia]").size).to eq(14)
    end

    it "opens the window and order of the address; a date that isn't one goes back to the default" do
      html = pagina(visao: "tempo", de: "2026-10-01", ordem: "prazo")
      expect([ html.css("[data-tempo-dia]").first["data-tempo-dia"], html.css("select[name=ordem] option[selected]").sole["value"] ]).to eq([ "2026-10-01", "prazo" ])
      expect(html.css("[data-tempo-passado]")).to be_present

      html = pagina(visao: "tempo", de: "ontem", ordem: "qualquer")
      expect([ html.css("[data-tempo-dia]").first["data-tempo-dia"], html.css("select[name=ordem] option[selected]").sole["value"] ]).to eq([ (Date.current - 2).iso8601, "chegada" ])
      expect(pagina.css("[data-painel-target=tempo]").sole.key?("hidden")).to be(true)
    end

    # Its record: a delivered pedido inside the window, linked to its resumo
    # (its stages are not read, so it has no faixa).
    it "shows the delivered inside the window, linked to its resumo" do
      entregue = pedido_calcado_confirmado.tap { |p| p.update_columns(status: "entregue", entregue_em: 1.day.ago) }
      barra = pagina(visao: "tempo").css("[data-tempo-grupo=entregues] #tempo_#{entregue.uuid}").sole
      expect([ barra.css("a.painel-tempo-resumo").sole["href"], barra.css(".painel-faixa").size ]).to eq([ resumo_pedido_path(entregue), 0 ])
    end
  end

  describe "a cliente final" do
    it "sees only his client's pedidos and none of the other's rows" do
      meu = pedido_calcado_confirmado
      outro = pedido_calcado_confirmado
      entrar_como_cliente_final(meu.client)

      get painel_path
      expect(response.body).to include(meu.uuid)
      expect(response.body).not_to include(outro.uuid)
      get itens_do_painel_path(outro.uuid)
      expect(response).to have_http_status(:not_found)
    end

    # Q4a: the previsão by day — the factory's queue behind it, but no
    # sectors, queue or turnos on his page.
    it "sees his previsão by day, with no sector, queue or turno" do
      turno_o_dia_todo
      ritmos_do_calcado
      pedido_calcado_confirmado
      meu = pedido_calcado_confirmado
      entrar_como_cliente_final(meu.client)
      get painel_path

      pagina = Nokogiri::HTML(response.body)
      expect(pagina.css(".painel-bloco-pedidos[data-bloco=hoje] > .painel-pedido").map { |p| p["data-uuid"] }).to eq([ meu.uuid ])
      expect(pagina.css("#painel_#{meu.uuid} [data-previsao]").text).to eq("hoje")
      expect(pagina.css(".painel-setores, [data-fila-setor], [data-painel-agora]")).to be_empty
      # Q4a: his pedidos' bars, by day; the factory's load is not his.
      expect(pagina.css("[data-tempo-grupo] .painel-tempo-pedido").map { |p| p["data-uuid"] }).to eq([ meu.uuid ])
      expect(pagina.css("[data-tempo-cargas]")).to be_empty
      expect(pagina.css("#tempo_#{meu.uuid} .painel-tdp [data-tdp-coluna] span")).to be_empty
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
