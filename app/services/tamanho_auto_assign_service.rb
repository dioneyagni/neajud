# Picks a tamanho for an arte right after its molde is chosen, so the user
# doesn't have to (019535b). First tries MoldMatchService (outline matching);
# if nothing matches, falls back to the first tamanho of the molde's corte —
# only when that corte is certain (Arquivo#corte_inequivoco_via_molde).
# Never overrides a tamanho already set.
#
# Usage: TamanhoAutoAssignService.call(arte)
class TamanhoAutoAssignService
  def self.call(arte, matcher: MoldMatchService)
    new(arte, matcher).call
  end

  def initialize(arte, matcher)
    @arte = arte
    @matcher = matcher
  end

  def call
    return if @arte.tamanho_id

    matched = @matcher.call(@arte)
    matched ? assign_match(matched) : assign_first_of_linked_corte
  end

  private

  # A match can come from a corte of another modelo; keep the arte's modelo_id
  # pointing at the corte it now uses (019535b: "sync modelo_id when match
  # selects a different corte").
  def assign_match(tamanho)
    @arte.update(tamanho_id: tamanho.id)
    corte = tamanho.arquivo
    return unless corte && corte.modelo_id != @arte.modelo_id

    @arte.update_column(:modelo_id, corte.modelo_id)
    @arte.reload
  end

  # Only when the corte is certain: with several cortes and no peça on the
  # arte it would be a guess, and the user picks the size instead.
  def assign_first_of_linked_corte
    first_tamanho = @arte.corte_inequivoco_via_molde&.tamanhos&.first
    @arte.update(tamanho_id: first_tamanho.id) if first_tamanho
  end
end
