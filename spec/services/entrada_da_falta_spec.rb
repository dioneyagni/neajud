require "rails_helper"
require_relative "../support/tecidos"
require_relative "../support/producao_calcado"

# Decided 05/11/2026: a baixa whose material is missing in the stock asks for
# its entry; whoever gives it knows the material came in, launches it with
# the baixa (more when more came), and needs the password of someone who may
# edit the stock if they may not. The entry stays if the baixa is undone.
RSpec.describe EntradaDaFalta do
  let(:client) { create(:client) }
  let(:oxford) { criar_tecido(grupo: "Oxford") }
  let(:papel) { criar_tecido(grupo: "Papel", cor: "Branco", tipo: "papel") }
  let(:estoquista) { create(:vinculo).user }
  let(:operador) { create(:vinculo, funcao: create(:funcao, acoes: %w[atualizar_producao], niveis: { "estoque" => 1 })).user }
  let(:pedido) { create(:pedido, tipo: "tecido", client: client) }

  before do
    (Empresa.atual || create(:empresa)).update!(papel_padrao: papel)
    pedido.itens_pedido.create!(arquivo: criar_obra_de_tecido("cor_lisa", client: client, no_catalogo: false, materia_prima: oxford, filename: "cor-x").arquivos.first,
                                materia_prima: oxford, metros: 4)
    pedido.update!(status: "confirmado")
    SaidaDoPedido.call(pedido)
  end

  def baixa(etapa, user: operador, **dados)
    RegistrarBaixaService.call(pedido, etapa: etapa, nivel: "pedido", medida: "4", confirmar: true, user: user, **dados)
  end

  def chave(material, dono = nil) = "#{material.uuid}:#{dono&.uuid || "empresa"}"
  def entradas = MovimentoEstoque.entradas.order(:id).map { |m| [ m.materia_prima, m.client, m.quantidade.to_f, m.lancado_por, m.autorizado_por ] }

  it "asks for the stage's own material only, saving nothing" do
    resultado = baixa("impressao")
    expect(resultado.estado).to eq(:falta_material)
    expect(resultado.faltas.map { |f| [ f.materia_prima, f.client, f.falta, f.minimo.to_f, f.chave ] }).to eq([ [ papel, nil, 4.0, 4.0, chave(papel) ] ])
    expect(pedido.baixas_producao.count).to eq(0)
  end

  it "launches the entry with the baixa, more when more came, by who may edit the stock" do
    expect(baixa("impressao", user: estoquista, entradas: { chave(papel) => "6,5" }).estado).to eq(:ok)
    expect(entradas).to eq([ [ papel, nil, 6.5, estoquista, nil ] ])
    expect(MovimentoEstoque.entradas.sole.lancada_na_baixa).to eq(pedido.baixas_producao.sole)
    expect(AguardandoMaterial.call.do_pedido(pedido).map(&:materia_prima)).to eq([ oxford ])
  end

  it "refuses less than what is missing, or what is not a number, saving nothing" do
    expect(baixa("impressao", user: estoquista, entradas: { chave(papel) => "3" }).mensagem).to eq("Entry of #{papel.nome_completo} 3 m is below the 4 m missing; expected at least that.")
    expect(baixa("impressao", user: estoquista, entradas: {}).mensagem).to eq(%(Entry of #{papel.nome_completo} "" is not a number of meters.))
    expect([ pedido.baixas_producao.count, entradas ]).to eq([ 0, [] ])
  end

  it "needs someone who may edit the stock to authorize with their password" do
    sem = baixa("impressao", entradas: { chave(papel) => "4" })
    errada = baixa("impressao", entradas: { chave(papel) => "4" }, autorizador: { email: estoquista.email_address, senha: "errada-123" })
    sem_permissao = baixa("impressao", entradas: { chave(papel) => "4" }, autorizador: { email: operador.email_address, senha: "senha-segura-123" })
    expect([ sem, errada, sem_permissao ].map(&:mensagem).uniq).to eq([ "Launching the entry needs the email and password of someone who may edit the stock." ])
    expect(entradas).to eq([])

    expect(baixa("impressao", entradas: { chave(papel) => "4" }, autorizador: { email: estoquista.email_address, senha: "senha-segura-123" }).estado).to eq(:ok)
    expect(entradas).to eq([ [ papel, nil, 4.0, operador, estoquista ] ])
  end

  it "refuses a deactivated authorizer" do
    estoquista.desativar!(por: nil)
    resultado = baixa("impressao", entradas: { chave(papel) => "4" }, autorizador: { email: estoquista.email_address, senha: "senha-segura-123" })
    expect(resultado.estado).to eq(:erro)
  end

  # Decided 05/11/2026: the material arrived either way.
  it "keeps the entry counting when the baixa is undone" do
    feita = baixa("impressao", user: estoquista, entradas: { chave(papel) => "4" }).baixa
    DesfazerBaixaService.call(feita, user: estoquista)
    expect(MovimentoEstoque.que_contam.entradas.where(materia_prima: papel).sum(:quantidade).to_f).to eq(4.0)
    expect(baixa("impressao").estado).to eq(:ok)
  end

  # The entries cover the oldest outs first: freeing this pedido covers an
  # older one waiting on the same material too.
  it "asks what frees the pedido, the older outs before it included" do
    antigo = create(:pedido, tipo: "tecido", client: client, status: "confirmado")
    antigo.movimentos_estoque.create!(materia_prima: papel, da_empresa: true, tipo: "saida", quantidade: 3, created_at: 1.day.ago)
    falta = baixa("impressao").faltas.sole
    expect([ falta.falta, falta.minimo.to_f ]).to eq([ 4.0, 7.0 ])
  end

  it "asks for the fabric of the Calandra's lines, with its owner" do
    estocar(papel)
    baixa("impressao")
    expect(baixa("calandra").faltas.map { |f| [ f.materia_prima, f.client, f.chave ] }).to eq([ [ oxford, client, chave(oxford, client) ] ])
  end

  it "asks nothing of a stage that takes no material" do
    calcado = pedido_calcado_confirmado
    SaidaDoPedido.call(calcado)
    MovimentoEstoque.where(pedido: calcado).saidas.find_each { |saida| estocar(saida.materia_prima, client: saida.client) }
    %w[impressao corte].each { |etapa| RegistrarBaixaService.call(calcado, etapa: etapa, nivel: "pedido", medida: "0", confirmar: true) }
    # The stock emptied again: the Estamparia takes nothing from it, so it doesn't ask.
    MovimentoEstoque.entradas.delete_all
    expect(RegistrarBaixaService.call(calcado, etapa: "estamparia", nivel: "pedido", medida: "10", confirmar: true).estado).to eq(:ok)
  end

  # Regression (05/11/2026): #d4f30331 was delivered skipping its Calandra,
  # the one stage that took its fabric — delivered, a pedido stops showing as
  # waiting, and the stock stayed short with no entry asked.
  describe "at the delivery" do
    def entregar(user: estoquista, **dados)
      EntregarPedidoService.call(pedido, confirmar: true, user: user, **dados)
    end

    it "asks for every material the pedido still waits for, delivering nothing" do
      resultado = entregar
      expect(resultado.estado).to eq(:falta_material)
      expect(resultado.faltas.map(&:chave)).to contain_exactly(chave(papel), chave(oxford, client))
      expect(pedido.reload.status).to eq("confirmado")
    end

    it "launches the entries with the delivery, pointing at the pedido" do
      expect(entregar(entradas: { chave(papel) => "4", chave(oxford, client) => "5" }).estado).to eq(:ok)
      expect(pedido.reload.status).to eq("entregue")
      expect(MovimentoEstoque.entradas.map { |m| [ m.materia_prima, m.quantidade.to_f, m.lancada_na_entrega, m.pedido_id ] })
        .to contain_exactly([ papel, 4.0, pedido, nil ], [ oxford, 5.0, pedido, nil ])
    end

    it "delivers nothing when the entry is refused" do
      resultado = entregar(user: operador, entradas: { chave(papel) => "4", chave(oxford, client) => "4" })
      expect([ resultado.estado, pedido.reload.status, entradas ]).to eq([ :erro, "confirmado", [] ])
    end

    it "asks nothing of a pedido whose material came in" do
      estocar(papel)
      estocar(oxford, client: client)
      expect(entregar.estado).to eq(:ok)
    end
  end
end
