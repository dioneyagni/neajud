# Lists the pieces an order item is made of, starting from the arte that was
# added to the pedido: one Slot per peça of the arte's molde, each with a
# file of that same arte for the peça, or arquivo nil when it has none
# (pending; Etapa 1.2, 3/3: the arte, not the molde's other artes).
# Pieces come from the molde's molde_pecas (its parts, chosen on the molde
# page — Etapa 1.1, 3/5); nothing is written here. The added arte is always present, even when its peça is
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
    # Parts belong to the molde only (Etapa 1.1, 3/5): no fallback to the
    # category's pieces any more.
    @molde.molde_pecas.includes(:peca).order(:id).map(&:peca).reject(&:excluido?)
  end

  # The files of the added arte's own envelope (Etapa 1.2, 3/3 parte 2): a
  # part is filled by a file of this arte, never by another arte of the molde
  # — the pedido reads the arte (decided 05/10/2026).
  def molde_artes
    @molde_artes ||= Arquivo.ativos.where(category: "artes", arte_id: @arte.arte_id, molde_id: @molde.id)
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
