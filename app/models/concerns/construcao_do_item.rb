# A tecido item's construção (Dublagem 4/5, decided 02/11/2026; plano Etapa
# 2.9 D1): the item keeps its superfície — the material the arte is printed
# on — and may name a construção whose superfície it is, to be dubbed into
# (decision 2). Only the empresa's construções or the pedido's client's
# serve (decision 3); changing the superfície lets go of one that no longer
# fits, and construcao_solta? says so for the message. Its dublado is
# charged at the construção's final price whoever owns the fabric (decision
# 4, PrecosDoItemTecido).
#
# Usage: item.update(construcao_uuid: construcao.uuid)
#        item.update(materia_prima: outro_tecido); item.construcao_solta? # => true
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
