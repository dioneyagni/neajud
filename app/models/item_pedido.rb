class ItemPedido < ApplicationRecord
  include GeraUuid
  include ReferenciaAtiva

  self.table_name = "itens_pedido"

  belongs_to :pedido
  belongs_to :arquivo
  belongs_to :materia_prima, optional: true
  recusa_excluido :pedido, :arquivo
  has_many :grades, class_name: "ItemPedidoGrade", dependent: :destroy
  has_many :item_pedido_pecas, -> { order(:position) }, dependent: :destroy

  # Stores one row per piece of the ordered molde.
  # Usage: item.compor_pecas!(MoldeComposicaoService.call(arte))
  def compor_pecas!(slots)
    slots.each_with_index do |slot, position|
      item_pedido_pecas.create!(peca: slot.peca, arquivo: slot.arquivo, position: position)
    end
  end

  # Unchecks the pieces whose arte was left unchecked in the modal; the pedido
  # goes to production without them. Unknown uuids are ignored.
  # Usage: item.excluir_pecas!(params[:excluir_arquivos])
  def excluir_pecas!(arquivo_uuids)
    arquivo_ids = Arquivo.where(uuid: Array(arquivo_uuids)).select(:id)
    item_pedido_pecas.where(arquivo_id: arquivo_ids).update_all(incluida: false)
  end

  # Copies pieces, including their checked/unchecked state, when confirmar
  # splits a pedido by client. Usage: novo_item.copiar_pecas_de!(item)
  def copiar_pecas_de!(source)
    source.item_pedido_pecas.each do |peca_row|
      item_pedido_pecas.create!(peca_row.slice(:peca_id, :arquivo_id, :incluida, :position))
    end
  end

  def quantidade_total
    grades.sum(:quantidade)
  end
end
