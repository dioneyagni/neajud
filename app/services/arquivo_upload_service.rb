# The "new arquivo from an uploaded file" flow, shared by the gallery upload
# (ArquivosController#create) and a pending piece's upload
# (PedidoPecasController#enviar_arte): fill filename/extension/category from
# the file, reject oversize files (reporting abuse) and extensions that don't
# match the real format, save, store version 1 and enqueue its processing —
# never inside the request (plano Etapa 0.3). The version starts "pending".
# Returns the arquivo: persisted on success, with errors otherwise.
#
# Usage: arquivo = ArquivoUploadService.call(upload, remote_ip: request.remote_ip,
#                                            arquivo: Arquivo.new(client_id: 3))
#        arquivo.persisted? # => true
class ArquivoUploadService
  MAX_FILE_SIZE = 1.gigabyte

  def self.call(upload, remote_ip:, arquivo: Arquivo.new)
    new(upload, remote_ip, arquivo).call
  end

  # [attribute, message] when the file's real format doesn't match extension,
  # nil when it does or can't be checked. Also used for new versions.
  # Usage: ArquivoUploadService.erro_de_tipo("tif", upload) # => [:extension, "declared 'TIF' but file is 'PNG'"]
  def self.erro_de_tipo(extension, upload)
    ext = extension.to_s.strip
    return nil if !upload.respond_to?(:tempfile) || ext.blank? || FileValidator::UNVERIFIABLE_EXTENSIONS.include?(ext)

    validator = FileValidator.new(upload.tempfile.path)
    real_fmt = validator.real_format
    return [ :original_file, "unable to identify file format" ] unless real_fmt
    return [ :extension, "declared '#{ext.upcase}' but file is '#{real_fmt}'" ] unless validator.valid_extension?(ext)

    nil
  end

  def initialize(upload, remote_ip, arquivo)
    @upload = upload
    @remote_ip = remote_ip
    @arquivo = arquivo
  end

  def call
    preencher_metadados
    return @arquivo unless tamanho_ok? && tipo_ok? && @arquivo.save

    ArquivoProcessingJob.perform_later(criar_versao!.id)
    @arquivo
  end

  private

  def preencher_metadados
    return unless @upload.respond_to?(:original_filename)

    @arquivo.filename = File.basename(@upload.original_filename, ".*") if @arquivo.filename.blank?
    @arquivo.extension = File.extname(@upload.original_filename).delete(".").downcase if @arquivo.extension.blank?
    @arquivo.mime_type = @upload.content_type if @arquivo.mime_type.blank?
    @arquivo.category = FileCategory.for_extension(@arquivo.extension) if @arquivo.category.blank?
    @arquivo.category_notes = FileCategory.notes(@arquivo.extension, @arquivo.category) if @arquivo.category_notes.blank?
  end

  def tamanho_ok?
    return true unless @upload.respond_to?(:tempfile)

    real_size = @upload.tempfile.size
    return true if real_size <= MAX_FILE_SIZE

    @arquivo.errors.add(:original_file, "exceeds maximum size of 1GB")
    AbuseDetectionJob.perform_later(ip_address: @remote_ip, file_size: real_size)
    false
  end

  def tipo_ok?
    erro = self.class.erro_de_tipo(@arquivo.extension, @upload)
    @arquivo.errors.add(*erro) if erro
    erro.nil?
  end

  def criar_versao!
    version = @arquivo.arquivo_versions.create!(
      version_number: 1, uuid: SecureRandom.uuid, filename: @arquivo.filename,
      extension: @arquivo.extension, mime_type: @arquivo.mime_type,
      original_file: @upload.original_filename, status: :pending, approved: true,
      category: @arquivo.category, category_notes: @arquivo.category_notes
    )
    @arquivo.update!(approved_version_id: version.id)
    version.store_original!(@upload)
    @arquivo.update!(
      filename: File.basename(@upload.original_filename, ".*"),
      extension: File.extname(@upload.original_filename).delete(".").downcase,
      mime_type: @upload.content_type
    )
    version
  end
end
