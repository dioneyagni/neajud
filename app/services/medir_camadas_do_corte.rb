# Fills a corte's sizes' lines by layer color (Painel 2/4a2, decided
# 06/11/2026) for cortes detected before they were kept: runs the detection
# again and writes only that column, each size found by its position —
# nothing is recreated, so the pedidos' references to the sizes stay.
# A size the detection no longer finds is left as it was (counted apart).
#
# Usage: MedirCamadasDoCorte.call(corte) # => #<Resultado medidos=5 sem_deteccao=0>
#        bin/rails cortes:medir_camadas  (every corte not measured yet)
class MedirCamadasDoCorte
  Resultado = Struct.new(:medidos, :sem_deteccao, keyword_init: true)

  # detector: answers #deteccao for the corte (DxfOrganizationService).
  def self.call(arquivo, detector: DxfOrganizationService.new(arquivo))
    deteccao = detector.deteccao
    return Resultado.new(medidos: 0, sem_deteccao: arquivo.tamanhos.size) unless deteccao

    por_posicao = deteccao["tamanhos"].index_by { |tamanho| tamanho["position"] }
    medidos = arquivo.tamanhos.select { |tamanho| por_posicao.dig(tamanho.position, "linhas_por_cor") }
    medidos.each { |tamanho| tamanho.update_columns(linhas_por_cor: por_posicao.dig(tamanho.position, "linhas_por_cor")) }
    Resultado.new(medidos: medidos.size, sem_deteccao: arquivo.tamanhos.size - medidos.size)
  end
end
