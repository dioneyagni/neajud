# A tecido item's construção (Dublagem 4/5, decided 02/11/2026; plano Etapa
# 2.9 D1): the item keeps its superfície — the material the arte is printed
# on — and may name a construção whose superfície it is, to be dubbed into
# (decision 2). Only the empresa's construções or the pedido's client's
# serve (decision 3); changing the superfície lets go of one that no longer
# fits, and construcao_solta? says so for the message. Its dublado is
# charged at the construção's final price whoever owns the fabric (decision
# 4, PrecosDoItemTecido). Dublagem 5a: when it dubs wholly before the
# estampa, production takes and prints on the dublado, from the stock.
#
# Usage: item.update(construcao_uuid: construcao.uuid)
#        item.update(materia_prima: outro_tecido); item.construcao_solta? # => true
#        item.material_da_producao # => the dublado, or the superfície
module ConstrucaoDoItem
  extend ActiveSupport::Concern

  included do
    belongs_to :construcao, optional: true
    atribui_por_uuid :construcao
    recusa_excluido :construcao
    before_validation :soltar_construcao_que_nao_serve, if: :will_save_change_to_materia_prima_id?
    validate :construcao_que_serve, if: -> { construcao && will_save_change_to_construcao_id? }
  end

  # The construção let go of on this save because the superfície changed.
  def construcao_solta? = @construcao_solta.present?

  attr_reader :construcao_solta

  # Why the construção no longer serves this item (nil when it does): the
  # superfície changed under it, or the pedido's client did.
  # Usage: item.motivo_da_construcao_que_nao_serve # => "é de outro cliente"
  def motivo_da_construcao_que_nao_serve
    return unless construcao
    return "a superfície dela não é #{materia_prima&.nome_completo || "o tecido do item"}" unless construcao.superficie&.materia_prima_id == materia_prima_id
    return "é de outro cliente" unless construcao.client_id.nil? || construcao.client_id == pedido&.client_id

    nil
  end

  # Dublagem 5a: the dublado comes from the stock — made by an ordem de
  # dublagem — when every ligação dubs before the estampa; one dubbed after
  # keeps the superfície until 5b.
  def dublado_do_estoque? = construcao.present? && construcao.dubla_antes?

  # Dublagem 5b1c1 (5b Q6a): with a dublagem after the Calandra, every letra
  # is made in the pedido (its Dublagem stages), none comes from the stock.
  def dublado_no_pedido? = construcao.present? && !construcao.dubla_antes?

  # The construção's letras this item is dubbed through, in the chave's
  # order. Usage: item.letras_da_dublagem.map(&:letra) # => ["DUB-A", "DUB-B"]
  def letras_da_dublagem = dublado_no_pedido? ? construcao.chave.dublagens : []

  # What the stock out and the Calandra take: the dublado, or the superfície.
  def material_da_producao = dublado_do_estoque? ? construcao.materia_prima : materia_prima

  # Whose that material is: the construção's owner for the dublado (a
  # client's construção is the pedido's client's), else the fabric's
  # (DonoDoTecido). Usage: item.dono_na_producao # => "empresa" or "cliente"
  def dono_na_producao
    return DonoDoTecido.do_item(self).dono unless dublado_do_estoque?

    construcao.client_id ? "cliente" : "empresa"
  end

  private

  def soltar_construcao_que_nao_serve
    return unless construcao && construcao.superficie&.materia_prima_id != materia_prima_id

    @construcao_solta = construcao
    self.construcao = nil
  end

  def construcao_que_serve
    motivo = motivo_da_construcao_que_nao_serve
    errors.add(:construcao, "\"#{construcao.nome}\" (#{construcao.uuid}) doesn't serve this item: #{motivo}") if motivo
  end
end
