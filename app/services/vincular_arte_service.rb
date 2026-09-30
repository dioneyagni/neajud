# Completes a pending piece with an existing arte ("Escolher arte"): links
# the arte to the item's molde and peça (and client, if it had none), logs
# the link, and fills the same pending peça in every draft pedido of that
# molde — the arte now belongs to the molde for good. Moving an arte out of
# another molde requires confirmar_mudanca: true (the user confirmed the
# "Mover para …?" prompt); otherwise NaoConfirmado is raised and nothing
# changes.
#
# Usage: VincularArteService.call(peca_row, arte, changed_by: request.remote_ip, user: Current.user, confirmar_mudanca: true)
class VincularArteService
  class Recusado < StandardError; end
  class NaoConfirmado < Recusado; end

  def self.call(peca_row, arte, changed_by:, user: nil, confirmar_mudanca: false)
    new(peca_row, arte, { changed_by: changed_by, user: user }, confirmar_mudanca).call
  end

  def initialize(peca_row, arte, autoria, confirmar_mudanca)
    @peca_row = peca_row
    @arte = arte
    @autoria = autoria
    @confirmar_mudanca = confirmar_mudanca
    @molde = peca_row.item_pedido.arquivo.molde
  end

  def call
    validar!
    ActiveRecord::Base.transaction do
      from_molde = @arte.molde
      vincular_arte!
      registrar!(from_molde)
      preencher_pendencias!
    end
    @arte
  end

  private

  def validar!
    raise Recusado, "Piece #{@peca_row.uuid} is not pending (it already has arte #{@peca_row.arquivo&.filename.inspect})" if @peca_row.arquivo
    # A nil peca_id would match every unknown-peça pending row below.
    raise Recusado, "Piece #{@peca_row.uuid} has no peça; only pieces of the molde can be completed" unless @peca_row.peca
    raise Recusado, "Arte #{@arte.filename.inspect} is not a candidate for peça #{@peca_row.peca&.nome.inspect} of molde #{@molde&.nome.inspect}" unless ArteCandidatasService.new(@peca_row).candidata?(@arte)
    return unless mudanca? && !@confirmar_mudanca

    raise NaoConfirmado, "Arte #{@arte.filename.inspect} is in molde #{@arte.molde.nome.inspect}; confirm moving it to #{@molde.nome.inspect}"
  end

  def mudanca?
    @arte.molde_id.present? && @arte.molde_id != @molde.id
  end

  def vincular_arte!
    @arte.update!(molde: @molde, peca: @peca_row.peca, client_id: @arte.client_id || @molde.client_id)
  end

  def registrar!(from_molde)
    @arte.vinculo_logs.create!(
      from_molde: from_molde == @molde ? nil : from_molde,
      from_molde_nome: from_molde == @molde ? nil : from_molde&.nome,
      to_molde: @molde, to_molde_nome: @molde.nome,
      peca: @peca_row.peca, pedido: @peca_row.item_pedido.pedido, **@autoria
    )
  end

  # This row plus the same pending peça in other draft pedidos of the molde.
  def preencher_pendencias!
    ItemPedidoPeca.pendentes.where(peca_id: @peca_row.peca_id)
                  .joins(item_pedido: [ :pedido, :arquivo ])
                  .where(pedidos: { status: "rascunho" }, arquivos: { molde_id: @molde.id })
                  .update_all(arquivo_id: @arte.id, incluida: true, updated_at: Time.current)
  end
end
