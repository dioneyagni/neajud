require "rails_helper"

# Painel 1/4: a pedido's stages in steps, from config/etapas_producao.yml's locks.
RSpec.describe CaminhoDoPedido do
  def passos(pedido)
    described_class.call(pedido).map { |passo| passo.map(&:chave) }
  end

  it "runs a calçado's Impressão and Corte side by side, then Estamparia, then Conferência" do
    expect(passos(build(:pedido, tipo: "calcado"))).to eq([ %w[impressao corte], %w[estamparia], %w[conferencia] ])
  end

  it "takes the tecido's Calandra after the Impressão" do
    expect(passos(build(:pedido, tipo: "tecido"))).to eq([ %w[impressao], %w[calandra] ])
  end

  it "leaves out the DTF's Corte on the roll" do
    expect(passos(build(:pedido, tipo: "dtf", entrega: "rolo"))).to eq([ %w[impressao] ])
    expect(passos(build(:pedido, tipo: "dtf", entrega: "cortada"))).to eq([ %w[impressao], %w[corte] ])
  end
end
