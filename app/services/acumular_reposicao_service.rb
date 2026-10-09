# Puts a Conferência's missing pieces in the pedido's open reposição
# (Etapa 2.2, 4/4; decided 09/10/2026): one per pedido, of the same client
# and type, "Reposição de #…", kept as rascunho — out of production — while
# it accumulates. The same line missing again adds its pieces (and keeps
# every stage either time asked to redo). It goes to production when the
# Conferência ends or by "Gerar reposição" (LiberarReposicaoService).
#
# Usage: AcumularReposicaoService.call(pedido, contagem.faltas) # => #<Pedido reposicao_de=pedido status="rascunho">
class AcumularReposicaoService
  def self.call(pedido, faltas)
    new(pedido, faltas).call
  end

  def initialize(pedido, faltas)
    @pedido = pedido
    @faltas = faltas
  end

  def call
    Pedido.transaction do
      reposicao = @pedido.reposicao_em_aberto ||
                  Pedido.create!(status: "rascunho", client: @pedido.client, tipo: @pedido.tipo, reposicao_de: @pedido)
      @faltas.each { |falta| acumular(reposicao, falta) }
      reposicao
    end
  end

  private

  def acumular(reposicao, falta)
    item = reposicao.itens_reposicao.find_or_initialize_by(**peca_da(falta.linha))
    item.update!(pecas: item.pecas.to_i + falta.pecas, corta: falta.linha.corte_chave.present?,
                 refazer_impressao: (item.persisted? && item.refazer_impressao) || falta.refazer_impressao,
                 refazer_corte: (item.persisted? && item.refazer_corte) || falta.refazer_corte)
  end

  # A reposição's line keeps pointing at the item of the first pedido.
  def peca_da(linha)
    { item_origem: linha.item, arquivo: linha.arquivo, peca: linha.peca, tamanho: linha.tamanho,
      materia_prima: linha.materia_prima, lado: linha.lado }
  end
end
