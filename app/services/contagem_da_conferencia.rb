# How many pieces each line of a reposição stage's baixa really had
# (Etapa 2.2, 4/4; decided 08-09/10/2026) — the Conferência. While the
# measure came short and the lines weren't counted, it asks for them
# (contar?, a line or a group alike); the count typed is the confirmation.
# Lines counted below their expected are the faltas, each with what the
# conferente left checked to redo — Impressão and/or Corte (09/10/2026).
#
# Usage: c = ContagemDaConferencia.new(nivel: "pedido", linhas: linhas, medida: "18", contagens: nil, refazer: nil)
#        c.contar? # => true (20 expected, counts not typed yet)
class ContagemDaConferencia
  ETAPAS_REFEITAS = %w[impressao corte].freeze

  Falta = Struct.new(:linha, :pecas, :refazer_impressao, :refazer_corte, keyword_init: true)

  def initialize(nivel:, linhas:, medida:, contagens:, refazer:)
    @nivel = nivel
    @linhas = linhas
    @medida = medida.to_d
    @contagens = contagens.presence&.to_h&.transform_keys(&:to_s)
    @refazer = refazer.to_h.transform_keys(&:to_s)
  end

  # Short and not counted yet.
  def contar?
    @contagens.nil? && @medida < esperado
  end

  # What each line starts with in the count: the measure typed for a single
  # line, else its expected.
  # Usage: contagem.inicial(linha) # => 8
  def inicial(linha)
    @nivel == "linha" ? @medida.to_i : linha.esperado.to_i
  end

  # Each covered line's count; a line not typed counts as its expected.
  def por_linha
    return @linhas.to_h { |l| [ l.chave, @contagens.fetch(l.chave, l.esperado).to_i ] } if @contagens

    @nivel == "linha" ? { @linhas.first.chave => @medida.to_i } : {}
  end

  def faltas
    @linhas.filter_map do |linha|
      contada = por_linha[linha.chave]
      next unless contada && contada < linha.esperado.to_i

      etapas = @refazer.fetch(linha.chave, ETAPAS_REFEITAS.join(",")).to_s.split(",")
      Falta.new(linha: linha, pecas: linha.esperado.to_i - contada, refazer_impressao: etapas.include?("impressao"), refazer_corte: etapas.include?("corte"))
    end
  end

  # The baixa's measure: the counts' sum when the lines were counted.
  def medida
    por_linha.any? ? por_linha.values.sum : @medida
  end

  def erro
    invalida = @contagens&.values&.find { |v| !v.to_s.match?(/\A\d+\z/) }
    "Count #{invalida.inspect} is not a number of pieces." if invalida
  end

  private

  def esperado
    @linhas.sum { |l| l.esperado.to_i }
  end
end
