# Sends the pedido's open reposição to production (Etapa 2.2, 4/4; decided
# 09/10/2026): by itself when the pedido's Conferência ends, or earlier by
# "Gerar reposição". Confirmed, it goes through its stages like any pedido;
# a later shortage opens a new one. Its pieces take their materials from
# the stock (Etapa 2.3d2, SaidaDoPedido).
#
# Usage: LiberarReposicaoService.call(pedido) # => the reposição, or nil when none is open
class LiberarReposicaoService
  def self.call(pedido)
    reposicao = pedido.reposicao_em_aberto
    return nil unless reposicao&.itens_reposicao&.exists?

    reposicao.update!(status: "confirmado")
    SaidaDoPedido.call(reposicao)
    reposicao
  end
end
