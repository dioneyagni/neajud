class ItemPedido < ApplicationRecord
  include GeraUuid
  include ReferenciaAtiva
  include PrecosDoItemTecido

  self.table_name = "itens_pedido"

  belongs_to :pedido
  # The arte ordered (Etapa 1.2, 3/3); arquivo is the file it was added from,
  # still what the pieces start from until the pedido reads them from the arte.
  belongs_to :arte
  belongs_to :arquivo
  before_validation { self.arte ||= arquivo&.arte }
  # A tecido item is an arte on a material (Etapa 2.7a, decided 16/10/2026):
  # its linear meters, one decimal, on a width — blank follows the material's.
  belongs_to :materia_prima, optional: true
  validates :metros, numericality: { greater_than_or_equal_to: 0, less_than: 100_000 }, allow_nil: true
  validate :metros_com_uma_casa
  validates :largura_mm, numericality: { only_integer: true, greater_than: 0, less_than: 10_000 }, allow_nil: true
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

  # Rebuilds the parts from the arte and its molde as they are now (a draft's
  # photo went stale: the molde gained or lost a part, or a file's part
  # became known — 42e40535 kept "Sem peça" next to an empty Cabedal). Each
  # part is matched by its peça, so an unchecked one stays unchecked and its
  # row keeps its uuid; a new part comes checked. Skipped for a trashed file.
  # Usage: item.recompor_pecas!
  def recompor_pecas!
    return if arquivo.excluido?

    linhas = item_pedido_pecas.to_a
    transaction do
      MoldeComposicaoService.call(arquivo).each_with_index do |slot, position|
        linha = linhas.find { |l| l.peca_id == slot.peca&.id }
        linhas.delete(linha)
        linha ? linha.update!(arquivo: slot.arquivo, position: position) : item_pedido_pecas.create!(peca: slot.peca, arquivo: slot.arquivo, position: position)
      end
      linhas.each(&:destroy!)
    end
  end

  def quantidade_total
    grades.sum(:quantidade)
  end

  # The width the tecido is printed on: the one typed on the pedido, else
  # the material's ("1,60 m" → 1600); nil when neither says.
  # Usage: item.largura_efetiva_mm # => 1600
  def largura_efetiva_mm
    largura_mm || materia_prima&.largura_mm
  end

  private

  # Checked on what was typed: the column's scale would round 12,55 to 12,6
  # silently. Not a number is numericality's.
  def metros_com_uma_casa
    digitado = metros_before_type_cast
    return if digitado.nil? || (BigDecimal(digitado.to_s) * 10).frac.zero?

    errors.add(:metros, "#{digitado} has more than one decimal; expected meters like 12,5")
  rescue ArgumentError
    nil
  end
end
