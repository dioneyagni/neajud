require "rails_helper"
require_relative "../support/construcoes"

# Dublagem 5b2b (Q4b, decided 12/11/2026): the cola short is a warning on
# the pages — the letra's line, the pedido's panel and the material's row —
# never a wait: the baixa goes on, the pedido isn't "aguardando material".
RSpec.describe "Cola na dublagem", type: :request do
  let(:cola) do
    grupo_de_dublagem("Cola").update!(unidade: "kg")
    MateriaPrima.create!(grupo_material: grupo_de_dublagem("Cola"), cor_material: CorMaterial.find_or_create_by!(nome: "Branco"), tipo: "filme", consumo_g_m2: 120)
  end
  let(:construcao) do
    construcao = Construcao.new(preco_final: 90)
    construcao.definir_camadas([ { materia_prima: material_de_dublagem("Oxford"), lado: "trama" },
                                 { materia_prima: material_de_dublagem("Espuma", densidade: "TC4"), ligante: cola, ordem_da_dublagem: 2 },
                                 { materia_prima: material_de_dublagem("Helanca"), ligante: cola, ordem_da_dublagem: 1 } ])
    construcao.tap(&:save!)
  end
  let(:pedido) do
    ComponentesDaDublagem.new(construcao).reject { |componente| componente.materia_prima == cola }.each do |componente|
      MovimentoEstoque.create!(materia_prima: componente.materia_prima, da_empresa: true, tipo: "entrada", quantidade: 10 * componente.por_metro)
    end
    pedido_dublado_confirmado(construcao, metros: 10, estoque: false)
  end

  def html = Nokogiri::HTML(response.body)

  it "warns on the letra's line, the pedido and the material, never as a wait" do
    get producao_tecido_pedido_path(pedido, etapa: "dublagem")
    linha = html.at_css("tr[data-letra='DUB-A']")
    expect(linha.at_css("[data-aviso-da-letra]").text).to eq("#{cola.nome_completo} · faltam 3,36 kg · não trava")
    expect(linha.at_css("[data-falta-da-letra]")).to be_nil

    get resumo_pedido_path(pedido)
    expect(html.at_css("[data-resumo='aviso-material']").text.squish).to eq("Falta no estoque: #{cola.nome_completo} · faltam 3,36 kg · não trava")
    # Q4b: nothing waits for the cola.
    expect(html.at_css("[data-resumo='aguardando']")).to be_nil

    get materiais_path
    expect(html.at_css("tr[data-material='#{cola.uuid}'] [data-aguardando]").text).to eq("Falta para 1 pedido · faltam 3,36 kg · não trava")
    expect(html.at_css("tr[data-material='#{cola.uuid}'] [data-saldo='empresa']").text).to eq("-3,36 kg")
  end
end
