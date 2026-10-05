# Picks a tamanho for an arte right after its molde is chosen, so the user
# doesn't have to (019535b). First the size read from the file name, when
# exactly one of the molde's sizes serves it (Etapa 1.2, 2/3: "…-29_30" or
# "…-30" → 29-30); then MoldMatchService (outline matching);
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

    matched = pelo_rotulo || @matcher.call(@arte)
    matched ? assign_match(matched) : assign_first_of_linked_corte
  end

  private

  # Only the file's part's cortes once its part is known: the Lateral and
  # the Língua both have a 29-30.
  def pelo_rotulo
    return nil if @arte.tamanho_rotulo.blank?

    cortes = Arquivo.cortes_do_molde(@arte.molde)
    cortes = cortes.where(peca_id: @arte.peca_id) if @arte.peca_id
    candidatos = Tamanho.where(arquivo_id: cortes.select(:id)).select { |t| t.atende_rotulo?(@arte.tamanho_rotulo) }
    candidatos.first if candidatos.size == 1
  end

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
