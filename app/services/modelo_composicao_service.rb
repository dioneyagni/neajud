# Lists the pieces an order item is made of, starting from the arte that was
# added to the pedido: one Slot per peça of the arte's modelo, each with the
# modelo's arte for that peça, or arquivo nil when none exists yet (pending).
# Pieces come from the modelo's modelo_pecas; if those were never synced (it
# happens lazily on the modelo page), from its molde — read-only, nothing is
# written here. The added arte is always present, even when its peça is
# unknown or not configured on the modelo. An arte without modelo is a
# single-piece composition.
#
# Usage: ModeloComposicaoService.call(arte)
#   # => [#<Slot peca=Lateral arquivo=arte>, #<Slot peca=Língua arquivo=nil>]
class ModeloComposicaoService
  Slot = Struct.new(:peca, :arquivo, keyword_init: true)

  def self.call(arte)
    new(arte).call
  end

  def initialize(arte)
    @arte = arte
    @modelo = arte.modelo
  end

  def call
    return [ Slot.new(peca: @arte.resolved_peca, arquivo: @arte) ] unless @modelo

    slots = modelo_pecas.map { |peca| Slot.new(peca: peca, arquivo: artes_by_peca_id[peca.id]) }
    slots + slots_outside_modelo_pecas(slots)
  end

  private

  def modelo_pecas
    configured = @modelo.modelo_pecas.includes(:peca).order(:id).map(&:peca)
    configured.presence || @modelo.molde&.pecas&.order(:id).to_a || []
  end

  def modelo_artes
    @modelo_artes ||= Arquivo.where(category: "artes", modelo_id: @modelo.id)
                             .includes(:peca, tamanho: { arquivo: :peca }).order(:id).to_a
  end

  def artes_by_peca_id
    @artes_by_peca_id ||= modelo_artes.select(&:resolved_peca).index_by { |arte| arte.resolved_peca.id }
  end

  # Artes whose peça isn't on the modelo (e.g. its molde changed later), plus
  # the added arte when its peça is unknown. Other artes without peça are left
  # out: they are candidates to fill a pending slot, not pieces yet.
  def slots_outside_modelo_pecas(slots)
    placed = slots.filter_map(&:arquivo)
    covered_peca_ids = slots.map { |slot| slot.peca.id }
    modelo_artes.reject { |arte| placed.include?(arte) }
                .select { |arte| outside?(arte, covered_peca_ids) }
                .map { |arte| Slot.new(peca: arte.resolved_peca, arquivo: arte) }
  end

  def outside?(arte, covered_peca_ids)
    peca = arte.resolved_peca
    peca ? !covered_peca_ids.include?(peca.id) : arte == @arte
  end
end
