# Moves a list of arquivos (by uuid) to the trash for the gallery's batch
# delete. Returns [trashed_uuids, errors], where errors holds unknown uuids.
# Files in storage stay (Etapa 0.4: nothing is physically deleted; restore
# from /lixeira).
#
# Usage: trashed_uuids, errors = ArquivoBatchDestroyService.call(params[:ids], changed_by: request.remote_ip)
class ArquivoBatchDestroyService
  def self.call(uuids, changed_by:)
    new(uuids, changed_by).call
  end

  def initialize(uuids, changed_by)
    @uuids = uuids
    @changed_by = changed_by
    @trashed_uuids = []
    @errors = []
  end

  # Bug fix (kept from the physical-delete version): each arquivo is handled
  # on its own, so one bad id fails alone without undoing the others, and the
  # returned uuids are only ever ones that actually committed.
  def call
    @uuids.each { |uuid| trash_one(uuid) }
    [ @trashed_uuids, @errors ]
  end

  private

  def trash_one(uuid)
    arquivo = Arquivo.ativos.find_by(uuid: uuid)
    return @errors << uuid unless arquivo

    arquivo.excluir!(changed_by: @changed_by)
    @trashed_uuids << uuid
  end
end
