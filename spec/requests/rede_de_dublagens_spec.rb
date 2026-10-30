require "rails_helper"

# Dublagem 2/5 (29/10/2026): the network, read only.
RSpec.describe "Rede de dublagens", type: :request do
  it "shows each ligação with its ligantes, situações, before/after, what was guessed and the warnings" do
    GrupoMaterial.create!(nome: "Oxford", superficie: true, base: true)

    get rede_de_dublagens_path

    html = Nokogiri::HTML(response.body)
    lona = html.at_css('.rede-ligacao[data-par="Oxford–Lona"]')
    expect(lona.text.squish).to include("Lona", "Filme 35 µm ou mais", "dubla antes", "a confirmar: antes/depois, situações", "Lona — não cadastrado")
    expect(lona.at_css('[data-situacao="tecido_molha"]').text.strip).to eq("Filme PU")
    expect(lona.at_css('[data-situacao="vai_frequencia"]').text.strip).to eq("—")
    expect(html.css(".rede-grupo h3").map(&:text)).to eq(%w[Oxford Espuma])
    expect(html.at_css('[data-contagem="ligacoes"]').text).to eq("#{RedeDeDublagens.ligacoes.size} ligações")
  end

  # The ligante is the factory's (plano Etapa 2.9): a cliente final never
  # sees the network, even with the stock open to him.
  it "is the team's only", sem_login: true do
    client = create(:client)
    funcao = create(:funcao, :para_cliente, niveis: { "estoque" => 1 })
    entrar_como(create(:vinculo, user: create(:user), client: client, funcao: funcao).user)

    get rede_de_dublagens_path
    expect(response).to have_http_status(:forbidden)
    get grupo_materiais_path
    expect(response.body).not_to include("Rede de dublagens")
  end

  it "is linked from Grupos" do
    get grupo_materiais_path
    expect(Nokogiri::HTML(response.body).at_css("a.rede-link")["href"]).to eq(rede_de_dublagens_path)
  end
end
