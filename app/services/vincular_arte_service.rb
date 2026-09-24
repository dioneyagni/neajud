# Completes a pending piece with an existing arte ("Escolher arte"): links
# the arte to the item's modelo and peça (and client, if it had none), logs
# the link, and fills the same pending peça in every draft pedido of that
# modelo — the arte now belongs to the modelo for good. Moving an arte out of
# another modelo requires confirmar_mudanca: true (the user confirmed the
# "Mover para …?" prompt); otherwise NaoConfirmado is raised and nothing
# changes.
#
# Usage: VincularArteService.call(peca_row, arte, changed_by: request.remote_ip, confirmar_mudanca: true)
class VincularArteService
  class Recusado < StandardError; end
  class NaoConfirmado < Recusado; end

  def self.call(peca_row, arte, changed_by:, confirmar_mudanca: false)
    new(peca_row, arte, changed_by, confirmar_mudanca).call
  end

  def initialize(peca_row, arte, changed_by, confirmar_mudanca)
    @peca_row = peca_row
    @arte = arte
    @changed_by = changed_by
    @confirmar_mudanca = confirmar_mudanca
    @modelo = peca_row.item_pedido.arquivo.modelo
  end

  def call
    validar!
    ActiveRecord::Base.transaction do
      from_modelo = @arte.modelo
      vincular_arte!
      registrar!(from_modelo)
      preencher_pendencias!
    end
    @arte
  end

  private

  def validar!
    raise Recusado, "Piece #{@peca_row.id} is not pending (it already has arte #{@peca_row.arquivo&.filename.inspect})" if @peca_row.arquivo
    # A nil peca_id would match every unknown-peça pending row below.
    raise Recusado, "Piece #{@peca_row.id} has no peça; only pieces of the modelo can be completed" unless @peca_row.peca
    raise Recusado, "Arte #{@arte.filename.inspect} is not a candidate for peça #{@peca_row.peca&.nome.inspect} of modelo #{@modelo&.nome.inspect}" unless ArteCandidatasService.new(@peca_row).candidata?(@arte)
    return unless mudanca? && !@confirmar_mudanca

    raise NaoConfirmado, "Arte #{@arte.filename.inspect} is in modelo #{@arte.modelo.nome.inspect}; confirm moving it to #{@modelo.nome.inspect}"
  end

  def mudanca?
    @arte.modelo_id.present? && @arte.modelo_id != @modelo.id
  end

  def vincular_arte!
    @arte.update!(modelo: @modelo, peca: @peca_row.peca, client_id: @arte.client_id || @modelo.client_id)
  end

  def registrar!(from_modelo)
    @arte.vinculo_logs.create!(
      from_modelo: from_modelo == @modelo ? nil : from_modelo,
      from_modelo_nome: from_modelo == @modelo ? nil : from_modelo&.nome,
      to_modelo: @modelo, to_modelo_nome: @modelo.nome,
      peca: @peca_row.peca, pedido: @peca_row.item_pedido.pedido, changed_by: @changed_by
    )
  end

  # This row plus the same pending peça in other draft pedidos of the modelo.
  def preencher_pendencias!
    ItemPedidoPeca.pendentes.where(peca_id: @peca_row.peca_id)
                  .joins(item_pedido: [ :pedido, :arquivo ])
                  .where(pedidos: { status: "rascunho" }, arquivos: { modelo_id: @modelo.id })
                  .update_all(arquivo_id: @arte.id, incluida: true, updated_at: Time.current)
  end
end
