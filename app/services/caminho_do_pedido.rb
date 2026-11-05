# The path a pedido's production takes (Painel 1/4): its stages in steps,
# from the locks of config/etapas_producao.yml — a stage locked by nothing
# starts the path, the others come one step after the last stage they wait
# for; stages of the same step run side by side. Dublagem 5b (Painel 4/4)
# will feed the dublagens in.
#
# Usage: CaminhoDoPedido.call(pedido).map { |passo| passo.map(&:nome) }
#   # => [["Impressão", "Corte"], ["Estamparia"], ["Conferência"]]
class CaminhoDoPedido
  def self.call(pedido)
    etapas = EtapasProducao.do_tipo(pedido.tipo, pedido: pedido)
    passos = {}
    etapas.each { |etapa| passos[etapa.chave] = passo_de(etapa, passos) }
    etapas.group_by { |etapa| passos[etapa.chave] }.sort.map(&:last)
  end

  # A lock of a stage this pedido skips (the DTF's Corte on the roll) counts as nothing.
  def self.passo_de(etapa, passos)
    anteriores = etapa.trava.filter_map { |trava| passos[trava] }
    anteriores.empty? ? 0 : anteriores.max + 1
  end
  private_class_method :passo_de
end
