# The same arte uploaded twice (same full name — molde, referência, nome, part,
# size): the newer file becomes a new version of the older arte, and the
# newer record goes to the trash (Etapa 1.1, 5/5). Asked from the newer
# arte's page ("Tornar nova versão dela"); the file is copied, not moved, so
# the trashed record can still be restored as it was.
#
# Usage: JuntarArteRepetidaService.call(repetida: nova, original: antiga, changed_by: ip, user: Current.user)
#   # => the new ArquivoVersion of `original`
class JuntarArteRepetidaService
  class Recusado < StandardError; end

  def self.call(repetida:, original:, changed_by:, user: nil)
    new(repetida, original, { changed_by: changed_by, user: user }).call
  end

  def initialize(repetida, original, autoria)
    @repetida = repetida
    @original = original
    @autoria = autoria
  end

  # No outer transaction: nova_versao! queues the processing, and a job
  # enqueued inside an open transaction may run before the version exists.
  def call
    validar!
    versao = @original.nova_versao!(nome_original: arquivo_de_origem.original_file, mime_type: arquivo_de_origem.mime_type) { |nova| copiar_para(nova) }
    @repetida.excluir!(**@autoria)
    versao
  end

  private

  def validar!
    unless @repetida.artes_com_mesmo_nome.include?(@original)
      raise Recusado, "#{@repetida.nome_completo.inspect} and #{@original.nome_completo.inspect} are not the same full name"
    end
    raise Recusado, "#{@repetida.filename.inspect} is already in a pedido; replace it there before joining it" if em_pedido?
    raise Recusado, "#{@repetida.filename.inspect} has no file to copy (version in use missing)" unless arquivo_de_origem && File.exist?(arquivo_de_origem.original_path)
  end

  def em_pedido?
    ItemPedido.exists?(arquivo_id: @repetida.id) || ItemPedidoPeca.exists?(arquivo_id: @repetida.id)
  end

  def arquivo_de_origem
    @repetida.approved_version
  end

  def copiar_para(nova)
    pasta = File.join(nova.storage_dir, "original")
    FileUtils.mkdir_p(pasta)
    FileUtils.cp(arquivo_de_origem.original_path, File.join(pasta, nova.original_file))
  end
end
