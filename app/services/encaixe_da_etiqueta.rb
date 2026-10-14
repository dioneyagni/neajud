# Each DTF size's fit on the film (Etapa 2.6b1, decided 13/10/2026): how
# many copies of the file fit across the film's useful width, with the
# etiqueta's spacing, and how much of the roll one row takes — standing and
# turned 90°. It doesn't depend on any quantity, so it is computed once per
# file and stored (arquivos.encaixe_dtf), when the file's measure, the
# arte's spacing or the dono's film change; a pedido only counts rows on it
# (EncaixeDoPedidoDtf). Plain arithmetic, run in the request.
#
#   { "medida_mm" => [16.17, 17.02], "largura_util_mm" => 570, "espacamento_mm" => 1.5,
#     "em_pe" => { "por_fileira" => 32, "passo_mm" => 18.52 },
#     "girada" => { "por_fileira" => 30, "passo_mm" => 17.67 } }
#
# An orientation that doesn't fit is nil; a file without size or DPI stores
# nil (the pedido shows it as a pendência).
#
# Usage: EncaixeDaEtiqueta.atualizar!(arquivo)
#        EncaixeDaEtiqueta.calcular([16.17, 17.02], largura_util_mm: 570, espacamento_mm: 1.5)
class EncaixeDaEtiqueta
  # Copies across and the row's step for one orientation; nil when it doesn't fit.
  # Usage: EncaixeDaEtiqueta.posicao(16.17, 17.02, 570, 1.5) # => { "por_fileira" => 32, "passo_mm" => 18.52 }
  def self.posicao(largura, altura, largura_util_mm, espacamento_mm)
    por_fileira = ((largura_util_mm + espacamento_mm) / (largura + espacamento_mm)).floor
    return nil unless por_fileira.positive?

    { "por_fileira" => por_fileira, "passo_mm" => (altura + espacamento_mm).round(2) }
  end

  # The fit of a measure on a film, both orientations.
  def self.calcular(medida_mm, largura_util_mm:, espacamento_mm:)
    return nil unless medida_mm && largura_util_mm && espacamento_mm

    largura, altura = medida_mm
    espacamento = espacamento_mm.to_f
    { "medida_mm" => medida_mm.map { |mm| mm.round(2) }, "largura_util_mm" => largura_util_mm, "espacamento_mm" => espacamento,
      "em_pe" => posicao(largura, altura, largura_util_mm, espacamento),
      "girada" => posicao(altura, largura, largura_util_mm, espacamento) }
  end

  # Recomputes one file's fit; a file outside a DTF keeps none.
  def self.atualizar!(arquivo, empresa: Empresa.atual)
    arte = arquivo.arte
    encaixe = (calcular(arquivo.approved_version&.medidas_mm, largura_util_mm: empresa&.largura_util_filme_dtf_mm, espacamento_mm: arte.espacamento_efetivo_mm) if arte&.tipo == "dtf")
    arquivo.update_column(:encaixe_dtf, encaixe) unless arquivo.encaixe_dtf == encaixe
  end

  # Every file of an arte (its spacing or kind changed).
  def self.atualizar_arte!(arte)
    arte.arquivos.includes(approved_version: :image_metadata).find_each { |arquivo| atualizar!(arquivo) }
  end

  # Every DTF file (the dono changed the film or the default spacing).
  def self.atualizar_todas!
    Arquivo.where(arte: Arte.where(tipo: "dtf")).includes(:arte, approved_version: :image_metadata).find_each { |arquivo| atualizar!(arquivo) }
  end
end
