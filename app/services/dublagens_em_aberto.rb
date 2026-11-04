# The dublagens em aberto (Dublagem 5a, decided 03/11/2026; plano Etapa 2.9
# D1): what the confirmed pedidos miss of each dublado made for the stock —
# per construção and owner, from AguardandoMaterial (a pedido took the
# dublado at confirmation and the stock didn't cover it) — less the meters
# of the ordens already generated. Computed on the fly, never stored: an
# ordem done brings the dublado in, and the falta goes by itself.
#
# Usage: abertas = DublagensEmAberto.call(aguardando: AguardandoMaterial.call, geradas: OrdemDublagem.geradas)
#        abertas.first.metros     # => 23.0 (to generate)
#        abertas.first.pedido_ids # => [42, 57]
class DublagensEmAberto
  Linha = Struct.new(:construcao, :client, :falta, :gerados, :pedido_ids, keyword_init: true) do
    def metros = (falta - gerados).round(2)
  end

  def self.call(aguardando:, geradas:)
    new(aguardando, geradas).call
  end

  def initialize(aguardando, geradas)
    @aguardando = aguardando
    # Without includes: joining the layers counted each ordem once per layer.
    @gerados = geradas.except(:includes).group(:construcao_id, :client_id).sum(:metros)
  end

  def call
    construcoes.filter_map { |construcao| linha(construcao) }.select { |linha| linha.metros.positive? }
  end

  private

  def construcoes
    Construcao.where(materia_prima_id: @aguardando.material_ids).includes(:client, :materia_prima, camadas: %i[materia_prima ligante]).order(:nome)
  end

  # Only the construção's own owner's falta: that is whose dublado the
  # pedidos take (ItemPedido#dono_na_producao).
  def linha(construcao)
    faltas = @aguardando.do_material(construcao.materia_prima).select { |falta| falta.client&.id == construcao.client_id }
    return if faltas.empty?

    Linha.new(construcao: construcao, client: construcao.client, falta: faltas.sum(&:metros), pedido_ids: faltas.map(&:pedido_id).uniq,
              gerados: @gerados[[ construcao.id, construcao.client_id ]].to_f)
  end
end
