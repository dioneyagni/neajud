require "rails_helper"
require_relative "../support/producao_dtf"

# Etapa 2.6b2 (decided 15/10/2026): the DTF's production — a line per
# etiqueta × size (D1), the Impressão in meters of film (D2), the Corte in
# units after printing, only when delivered cut (D3).
RSpec.describe "The DTF's production" do
  let(:pedido) { pedido_dtf_confirmado }
  # P standing and G turned, each its own etiqueta (one turn mark per etiqueta).
  let(:itens) { pedido.itens_pedido.order(:id).to_a }

  def etapa(chave) = EtapasProducao.etapa("dtf", chave, pedido: pedido)
  def linhas(chave) = LinhasDeProducao.call(pedido, etapa(chave))
  def baixa(chave, nivel, medida, alvo: nil, confirmar: false)
    RegistrarBaixaService.call(pedido, etapa: chave, nivel: nivel, alvo: alvo, medida: medida, confirmar: confirmar)
  end

  it "keys a line per etiqueta × size, expecting the film's meters or the units printed" do
    impressao = linhas("impressao")
    p_, g = impressao
    expect(impressao.map(&:chave)).to eq([ "#{itens[0].uuid}/P/#{p_.arquivo.uuid}", "#{itens[1].uuid}/G/#{g.arquivo.uuid}" ])
    expect(impressao.map { |l| [ l.referencia, l.encaixe.girada, l.pecas, l.esperado ] }).to eq([
      [ itens[0].uuid, false, 44, p_.encaixe.metros ], [ itens[1].uuid, true, 18, g.encaixe.metros ]
    ])
    expect(linhas("corte").map(&:esperado)).to eq([ 44, 18 ])
  end

  it "reads the fit written at confirmation, not the file's current one" do
    antes = linhas("impressao").map(&:esperado)
    Empresa.atual.update!(largura_filme_dtf_mm: 300)
    expect(linhas("impressao").map(&:esperado)).to eq(antes)
  end

  it "takes the Impressão's baixa by etiqueta in meters, warning outside the dono's band" do
    esperado = linhas("impressao").first.esperado
    expect(baixa("impressao", "referencia", "5", alvo: itens[0].uuid).estado).to eq(:aviso)
    resultado = baixa("impressao", "referencia", esperado.to_s, alvo: itens[0].uuid)
    expect([ resultado.estado, resultado.baixa.linhas.size, pedido.reload.status ]).to eq([ :ok, 1, "em_producao" ])
  end

  it "cuts a line only after it is printed, in units" do
    g = linhas("impressao").last
    expect(baixa("corte", "linha", "18", alvo: g.chave).mensagem).to eq("Waiting for Impressão: this line can't have its Corte baixa yet.")
    baixa("impressao", "linha", g.esperado.to_s, alvo: g.chave)
    expect(baixa("corte", "linha", "18", alvo: g.chave).estado).to eq(:ok)
    expect(AndamentoDoPedido.call(pedido).map { |a| [ a.etapa.chave, a.feitas, a.total ] }).to eq([ [ "impressao", 1, 2 ], [ "corte", 1, 2 ] ])
  end

  # On the roll nothing is cut: no Corte to wait for, none to give.
  context "delivered on the roll" do
    let(:pedido) { pedido_dtf_confirmado(entrega: "rolo") }

    it "has only the Impressão, and delivering waits for nothing else" do
      expect(AndamentoDoPedido.call(pedido).map { |a| a.etapa.chave }).to eq(%w[impressao])
      expect { baixa("corte", "pedido", "58") }.to raise_error(EtapasProducao::Invalida)
      baixa("impressao", "pedido", linhas("impressao").sum(&:esperado).to_s)
      expect(EntregarPedidoService.call(pedido).estado).to eq(:ok)
    end
  end
end
