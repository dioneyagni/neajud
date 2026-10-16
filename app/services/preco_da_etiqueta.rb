# An etiqueta DTF size's unit price (Etapa 2.6c, decided 14/10/2026): the
# price per meter ÷ the units one meter of film holds (in the orientation
# the etiqueta goes — Arte#orientacao_dtf, decided 16/10/2026), rounded up
# to the cent. Calculated when the etiqueta is
# fitted (EncaixeDaEtiqueta) and kept in arquivos.preco_unidade_calculado,
# from its client's price per meter — the dono's when it has none or is a
# catálogo work (the same for everyone, D4). A pedido recalculates it with
# the ordering client's own price per meter (EncaixeDoPedidoDtf's cascade).
#
# Usage: PrecoDaEtiqueta.unitario(arquivo.encaixe_dtf, 120, "em_pe") # => 0.24
#        PrecoDaEtiqueta.calculado(arquivo)                  # => 0.24
module PrecoDaEtiqueta
  # Units one meter of film holds in one orientation ("em_pe" / "girada"):
  # rows per meter × copies per row (nil without a fit, or when it doesn't
  # fit that way).
  # Usage: PrecoDaEtiqueta.unidades_por_metro(encaixe, "em_pe") # => 1727.9
  def self.unidades_por_metro(encaixe, orientacao)
    posicao = encaixe&.dig(orientacao)
    return nil unless posicao

    posicao["por_fileira"] * 1000.0 / posicao["passo_mm"]
  end

  def self.unitario(encaixe, preco_metro, orientacao)
    unidades = unidades_por_metro(encaixe, orientacao)
    return nil unless unidades && preco_metro

    (preco_metro.to_d * 100 / unidades.to_d).ceil.to_d / 100
  end

  # The price per meter an etiqueta's own price comes from.
  def self.preco_metro_de(arquivo, empresa: Empresa.atual)
    proprio = arquivo.client&.preco_metro_dtf unless arquivo.arte&.no_catalogo
    proprio || empresa&.preco_metro_dtf
  end

  def self.calculado(arquivo, encaixe = arquivo.encaixe_dtf)
    unitario(encaixe, preco_metro_de(arquivo), arquivo.arte.orientacao_dtf)
  end
end
