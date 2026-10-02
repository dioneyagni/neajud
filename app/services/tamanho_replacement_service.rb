# Saves a corte's tamanhos from the Mold Organization form (rows keyed "0",
# "1", … and ordered numerically) — Etapa 1.2 (1/3): read with the corte's
# grade type (GradeDoCorte: the label and the individual sizes it serves).
#
# Rows are matched to the existing tamanhos by position and **updated in
# place**: their previews, extracted DXFs, uuid and the artes linked to them
# stay. Before, every save destroyed and recreated them, unlinking every arte
# — so re-saving an organization to set its grade type would have cut the
# artes off their sizes. Only tamanhos past the new list are removed (and
# their artes unlinked).
#
# Everything is read before anything is written: `erro` tells why a row was
# refused, and `call` refuses to run then.
#
# Usage:
#   substituicao = TamanhoReplacementService.new(corte, params[:tamanhos], tipo: "par")
#   substituicao.erro # => nil, or "Size 2: \"30-31\" isn't a Par pair; …"
#   substituicao.call
class TamanhoReplacementService
  FIELDS = %w[nome tamanhos rotulo width_mm height_mm area_mm2].freeze
  MEDIDAS = %w[width_mm height_mm area_mm2].freeze

  attr_reader :erro

  # Kept for callers without a grade type (the name is the label).
  def self.call(corte, submitted, tipo: nil)
    new(corte, submitted, tipo: tipo).call
  end

  def initialize(corte, submitted, tipo: nil)
    @corte = corte
    @tipo = tipo.presence
    @linhas = ler_linhas(submitted)
  rescue GradeDoCorte::Invalido => e
    @erro = e.message
  end

  def call
    raise ArgumentError, "Refused tamanhos for #{@corte.filename.inspect}: #{erro}" if erro

    existentes = @corte.tamanhos.index_by(&:position)
    @linhas.each.with_index(1) { |linha, posicao| salvar(existentes.delete(posicao), linha, posicao) }
    remover(existentes.values)
  end

  private

  def ler_linhas(submitted)
    raw = submitted.is_a?(ActionController::Parameters) ? submitted.to_unsafe_h : submitted
    raw.sort_by { |key, _| key.to_i }.each.with_index(1).map do |(_, row), posicao|
      row = row.slice(*FIELDS)
      ler_grade(row, posicao).merge(row.slice(*MEDIDAS).symbolize_keys)
    end
  end

  def ler_grade(row, posicao)
    # No grade type yet: what was typed is just the name, as before 1.2.
    return { nome: row["tamanhos"].presence || row["nome"].presence || "Size #{posicao}", numeros: [] } unless @tipo

    GradeDoCorte.ler(@tipo, rotulo: row["rotulo"], tamanhos: row["tamanhos"].presence || row["nome"])
  rescue GradeDoCorte::Invalido => e
    raise GradeDoCorte::Invalido, "Size #{posicao}: #{e.message}"
  end

  def salvar(tamanho, linha, posicao)
    atributos = linha.merge(position: posicao)
    tamanho ? tamanho.update!(atributos) : @corte.tamanhos.create!(atributos)
  end

  def remover(tamanhos)
    Arquivo.where(tamanho_id: tamanhos.map(&:id)).update_all(tamanho_id: nil)
    tamanhos.each(&:destroy!)
  end
end
