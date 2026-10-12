# Keeps the parts of draft pedidos' items in step with their arte and molde
# (decided 09/10/2026): the parts were a photo taken when the arte was added,
# so a molde that gained or lost a part, or a file whose part became known,
# left a draft with stale rows. Confirmed pedidos keep theirs; one sent to
# the factory (Etapa 2.8, 5/5) is still a draft here.
#
# Usage: RecomporRascunhos.da_arte([arte_id])   # a file of the arte changed
#        RecomporRascunhos.do_molde(molde)      # a part was added or removed
#        RecomporRascunhos.todos                # every draft (bin/rails pedidos:recompor_rascunhos)
class RecomporRascunhos
  def self.da_arte(arte_ids)
    recompor(itens_em_rascunho.where(arte_id: Array(arte_ids).compact))
  end

  def self.do_molde(molde)
    recompor(itens_em_rascunho.where(arquivo: Arquivo.where(molde_id: molde.id)))
  end

  # Returns how many items were rebuilt.
  def self.todos
    recompor(itens_em_rascunho)
  end

  def self.itens_em_rascunho
    ItemPedido.joins(:pedido).merge(Pedido.ativos.nao_confirmados)
  end
  private_class_method :itens_em_rascunho

  def self.recompor(itens)
    itens.includes(:arquivo, :item_pedido_pecas).find_each(&:recompor_pecas!)
    itens.count
  end
  private_class_method :recompor
end
