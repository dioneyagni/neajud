# Destroys a list of arquivos by uuid for the gallery's batch delete, then
# removes each destroyed arquivo's storage folder. Returns
# [destroyed_uuids, errors], where errors holds unknown uuids and
# { uuid:, error: } for arquivos that refused to be destroyed.
#
# Usage: destroyed_uuids, errors = ArquivoBatchDestroyService.call(params[:ids])
class ArquivoBatchDestroyService
  def self.call(uuids)
    new(uuids).call
  end

  def initialize(uuids)
    @uuids = uuids
    @destroyed_uuids = []
    @errors = []
  end

  # Bug fix: this used to wrap every id in ONE transaction and roll the
  # whole thing back on the first failure, yet still reported the
  # already-rolled-back items as destroyed (destroyed/errors were plain Ruby
  # counters, unaffected by the DB rollback). Destroying each arquivo in its
  # own (implicit) transaction makes one bad id fail on its own without
  # undoing the others, and the returned uuids are only ever ones that
  # actually committed. Also never removed storage/stamps/:uuid — this
  # service now does that for each returned uuid.
  def call
    @uuids.each { |uuid| destroy_one(uuid) }
    @destroyed_uuids.each { |uuid| FileUtils.rm_rf(File.join(ArquivoVersion::STORAGE_BASE, uuid)) }
    [ @destroyed_uuids, @errors ]
  end

  private

  def destroy_one(uuid)
    arquivo = Arquivo.find_by(uuid: uuid)
    return @errors << uuid unless arquivo
    return @destroyed_uuids << uuid if arquivo.destroy

    @errors << { uuid: uuid, error: arquivo.errors[:base].to_sentence.presence || "could not be deleted" }
  end
end
