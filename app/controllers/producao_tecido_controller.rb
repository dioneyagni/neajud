# A tecido pedido's production (Etapa 2.7c, decided 19/10/2026): one page
# for its Impressão (the paper) and Calandra (onto the fabric, after the
# line's paper), a line per item (arte × fabric) with its baixa in meters,
# and each item's file for the RIP — compacted at upload, the meters and
# the width in its name — alone or every one in a .zip. The page and the
# downloads are ProducaoSemCorte's.
#
# Usage: GET /pedidos/:uuid/tecido/producao/calandra
#        GET /pedidos/:uuid/tecido/arquivo?linha=<key>
#        GET /pedidos/:uuid/tecido/arquivos (.zip)
#        GET /pedidos/:uuid/tecido/compactados (JSON: are the copies ready?)
class ProducaoTecidoController < ApplicationController
  include ProducaoSemCorte

  private

  def tipo_da_producao
    "tecido"
  end

  def rip_da(linha)
    ArquivoTecidoParaRip.new(linha)
  end

  def caminho_da_producao(etapa)
    producao_tecido_pedido_path(@pedido, etapa: etapa)
  end

  def aviso_preparando(quantos)
    quantos == 1 ? "O arquivo compactado ainda está sendo preparado" : "#{quantos} arquivos compactados ainda estão sendo preparados"
  end
end
