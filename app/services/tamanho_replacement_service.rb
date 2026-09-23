# Replaces a corte's tamanhos with the list submitted by the Mold Organization
# form (keyed "0", "1", … and ordered numerically). Preview images are kept by
# position, since the form only sends names and measurements. Artes linked to
# the old tamanhos are unlinked first: those rows are destroyed, and the arte
# must be re-matched against the new list.
#
# Usage: TamanhoReplacementService.call(corte, params[:tamanhos])
class TamanhoReplacementService
  FIELDS = %w[nome position width_mm height_mm area_mm2].freeze

  def self.call(corte, submitted)
    new(corte, submitted).call
  end

  def initialize(corte, submitted)
    @corte = corte
    @submitted = submitted
  end

  def call
    previews_by_position = @corte.tamanhos.to_h { |t| [ t.position, t.preview_file ] }
    Arquivo.where(tamanho_id: @corte.tamanhos.pluck(:id)).update_all(tamanho_id: nil)
    @corte.tamanhos.destroy_all
    ordered_rows.each.with_index(1) do |row, position|
      create_tamanho(row, position, previews_by_position[position])
    end
  end

  private

  def ordered_rows
    raw = @submitted.is_a?(ActionController::Parameters) ? @submitted.to_unsafe_h : @submitted
    raw.sort_by { |key, _| key.to_i }.map { |_, row| row.is_a?(Hash) ? row.slice(*FIELDS) : row }
  end

  def create_tamanho(row, position, preview)
    @corte.tamanhos.create!(
      nome: row["nome"].presence || "Size #{position}",
      position: position,
      width_mm: row["width_mm"],
      height_mm: row["height_mm"],
      area_mm2: row["area_mm2"],
      preview_file: preview
    )
  end
end
