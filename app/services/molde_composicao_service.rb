# Lists the pieces an order item is made of, starting from the arte that was
# added to the pedido: one Slot per peça of the arte's molde, each with the
# molde's arte for that peça, or arquivo nil when none exists yet (pending).
# Pieces come from the molde's molde_pecas; if those were never synced (it
# happens lazily on the molde page), from its modelo — read-only, nothing is
# written here. The added arte is always present, even when its peça is
# unknown or not configured on the molde. An arte without molde is a
# single-piece composition.
#
# Usage: MoldeComposicaoService.call(arte)
#   # => [#<Slot peca=Lateral arquivo=arte>, #<Slot peca=Língua arquivo=nil>]
class MoldeComposicaoService
  Slot = Struct.new(:peca, :arquivo, keyword_init: true)

  def self.call(arte)
    new(arte).call
  end

  def initialize(arte)
    @arte = arte
    @molde = arte.molde
  end

  def call
    return [ Slot.new(peca: @arte.resolved_peca, arquivo: @arte) ] unless @molde

    slots = molde_pecas.map { |peca| Slot.new(peca: peca, arquivo: artes_by_peca_id[peca.id]) }
    slots + slots_outside_molde_pecas(slots)
  end

  private

  def molde_pecas
    configured = @molde.molde_pecas.includes(:peca).order(:id).map(&:peca).reject(&:excluido?)
    configured.presence || @molde.modelo&.pecas&.ativos&.order(:id).to_a || []
  end

  def molde_artes
    @molde_artes ||= Arquivo.ativos.where(category: "artes", molde_id: @molde.id)
                             .includes(:peca, tamanho: { arquivo: :peca }).order(:id).to_a
  end

  def artes_by_peca_id
    @artes_by_peca_id ||= molde_artes.select(&:resolved_peca)
                                      .index_by { |arte| arte.resolved_peca.id }
                                      .merge(added_arte_by_peca_id)
  end

  # The added arte always wins its own peça. Real data had two línguas on one
  # molde (a misfiled arte); without this, adding one of them showed the other.
  def added_arte_by_peca_id
    peca = @arte.resolved_peca
    peca && @arte.molde_id == @molde.id ? { peca.id => @arte } : {}
  end

  # Artes whose peça isn't on the molde (e.g. its modelo changed later), plus
  # the added arte when its peça is unknown. Other artes without peça are left
  # out: they are candidates to fill a pending slot, not pieces yet.
  def slots_outside_molde_pecas(slots)
    placed = slots.filter_map(&:arquivo)
    covered_peca_ids = slots.map { |slot| slot.peca.id }
    molde_artes.reject { |arte| placed.include?(arte) }
                .select { |arte| outside?(arte, covered_peca_ids) }
                .map { |arte| Slot.new(peca: arte.resolved_peca, arquivo: arte) }
  end

  def outside?(arte, covered_peca_ids)
    peca = arte.resolved_peca
    peca ? !covered_peca_ids.include?(peca.id) : arte == @arte
  end
end
