require "rails_helper"

# Máquinas 1/5 (decided 20/11/2026, canvas "Máquinas"): the list, a machine's
# page, the trash, and Ritmos reading the machines.
RSpec.describe "Máquinas", type: :request do
  def trabalhos(**por_chave)
    por_chave.transform_values { |valor| valor.is_a?(Hash) ? valor.merge(marcado: "1") : { marcado: "1", por_hora: valor } }
  end

  def criar(nome = "Calandra 2", **por_chave)
    post parametros_maquinas_path, params: { maquina: { nome: nome, trabalhos: trabalhos(**por_chave) } }
  end

  it "lists each trabalho with its machines and informado, none falling back to Ritmos" do
    RitmoProducao.create!(tipo: "dtf", etapa: "impressao", por_hora: 10)
    criar("Calandra 2", calandra: "40", dublagem: "30")
    criar("Calandra 3", calandra: "40")
    get parametros_maquinas_path
    linha = ->(chave) { response.body[/data-trabalho="#{chave}">.*?<\/tr>/m].delete_prefix("data-trabalho=\"#{chave}\">").gsub(/<[^>]+>/, " ").squish }
    expect(linha.call("calandra")).to eq("Calandra · tecido Calandra 2 · Calandra 3 80 m/h")
    expect(linha.call("impressao_dtf")).to eq("Impressão DTF nenhuma — usa o ritmo de Ritmos 10 m/h")
    expect(linha.call("impressao_papel")).to include("Calçado sem ritmo · Tecido sem ritmo")
    expect(linha.call("corte_calcado")).to include("pelos parâmetros de Ritmos")
    expect(response.body).to include("Calandra · 40 m/h", "Dublagem · 30 m/h")
  end

  it "creates a machine and opens its page with the histórico" do
    expect { criar(calandra: "40") }.to change(Maquina, :count).by(1)
    expect([ response, flash[:notice] ]).to match([ redirect_to(parametros_maquinas_path), "Calandra 2: salva." ])
    get edit_parametros_maquina_path(Maquina.sole)
    expect(response.body).to include('value="40"', "criou com Calandra 40 m/h", 'name="maquina[trabalhos][calandra][marcado]"')
  end

  it "answers a refused machine on its page with what was typed" do
    criar("Mesa", calandra: "")
    expect(response).to have_http_status(:unprocessable_content)
    expect(response.body).to include("Calandra: Velocidade precisa ser mais que 0", 'value="Mesa"')
    post parametros_maquinas_path, params: { maquina: { nome: "Mesa", trabalhos: {} } }
    expect(response.body).to include("Marque pelo menos um trabalho que a máquina faz.")
    expect(Maquina.count).to eq(0)
  end

  it "edits it: unchecking a trabalho removes it" do
    criar(calandra: "40", dublagem: "30")
    maquina = Maquina.sole
    patch parametros_maquina_path(maquina), params: { maquina: { nome: "Calandra 2", trabalhos: trabalhos(calandra: "50").merge(dublagem: { marcado: "0", por_hora: "30" }) } }
    expect(maquina.reload.trabalhos.map(&:descricao)).to eq([ "Calandra 50 m/h" ])
    expect(maquina.alteracoes.recentes.first.texto).to eq("Calandra 40 m/h → 50 m/h; tirou Dublagem")
  end

  it "sends it to the trash and back, its name still taken there" do
    criar(calandra: "40")
    maquina = Maquina.sole
    delete parametros_maquina_path(maquina)
    expect([ maquina.reload.excluido?, flash[:notice] ]).to eq([ true, "Calandra 2: foi para a lixeira." ])
    get parametros_maquinas_path
    expect(response.body).not_to include("data-maquina=\"Calandra 2\"")
    criar(calandra: "40")
    expect(response.body).to include("está na lixeira")
    patch parametros_maquina_path(maquina), params: { maquina: { nome: "X", trabalhos: trabalhos(calandra: "40") } }
    expect([ maquina.reload.nome, flash[:alert] ]).to eq([ "Calandra 2", "Calandra 2 está na lixeira: restaure-a na Lixeira para mudar." ])
    get lixeira_path
    expect(response.body).to include("Máquinas (1)")
    post restaurar_lixeira_path(tipo: "maquinas", id: maquina.uuid)
    expect([ maquina.reload.excluido?, flash[:notice] ]).to eq([ false, 'Máquina "Calandra 2" restored.' ])
  end

  describe "in Ritmos" do
    it "shows a row with machines read only, and saving keeps what was typed there" do
      RitmoProducao.create!(tipo: "tecido", etapa: "calandra", por_hora: 25)
      criar(calandra: "40")
      criar("Calandra 3", calandra: "40")
      criar("Mesa 1", corte_calcado: { velocidade_mm_s: "120" })
      get edit_parametros_ritmos_path
      calandra = response.body[/data-ritmo="tecido:calandra".*?<\/tr>/m]
      expect(calandra.gsub(/<[^>]+>/, " ").squish).to include("80 m/h · 2 máquinas · ver máquinas", "80 m/h yours")
      expect(calandra).not_to include("[por_hora]")
      corte = response.body[/data-ritmo="calcado:corte".*?<\/tr>/m]
      expect(corte.gsub(/<[^>]+>/, " ").squish).to include("pelos parâmetros de 1 máquina · ver máquinas")
      expect(corte).not_to include("[velocidade_mm_s]")

      patch parametros_ritmos_path, params: { ritmos: { tecido: { calandra: { por_hora: "99", fixar_informado: "1" } }, calcado: { corte: { velocidade_mm_s: "5" } } } }
      expect(RitmoProducao.pluck(:etapa, :por_hora, :fixar_informado, :velocidade_mm_s)).to eq([ [ "calandra", 25, true, nil ] ])
    end
  end
end
