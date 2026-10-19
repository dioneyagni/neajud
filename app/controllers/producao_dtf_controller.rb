# A DTF pedido's production (Etapa 2.6b2, decided 15/10/2026): one page for
# its Impressão and Corte (the Corte only when delivered cut, D3), a line
# per etiqueta × size (D1) with its baixa, and each line's file for the RIP
# (D4: turned 90° when the fit turned it, the units in the name) — alone or
# every one in a .zip. The page and the downloads are ProducaoSemCorte's.
#
# Usage: GET /pedidos/:uuid/dtf/producao/impressao
#        GET /pedidos/:uuid/dtf/arquivo?linha=<key>
#        GET /pedidos/:uuid/dtf/arquivos (.zip)
#        GET /pedidos/:uuid/dtf/girados (JSON: are the turned copies ready?)
class ProducaoDtfController < ApplicationController
  include ProducaoSemCorte

  private

  def tipo_da_producao
    "dtf"
  end

  def rip_da(linha)
    ArquivoDtfParaRip.new(linha)
  end

  def caminho_da_producao(etapa)
    producao_dtf_pedido_path(@pedido, etapa: etapa)
  end

  def aviso_preparando(quantos)
    quantos == 1 ? "O arquivo girado ainda está sendo preparado" : "#{quantos} arquivos girados ainda estão sendo preparados"
  end
end
