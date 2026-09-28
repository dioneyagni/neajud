# Checks and stores the optional attachment of an art approval (a WhatsApp
# print, an email as PDF). The type comes from the file's first bytes — never
# the extension or the browser's MIME — and nothing parses it: a PDF is not
# opened by ImageMagick/Ghostscript inside the request (docs/plano.md,
# "Segurança de arquivos").
#
# Usage: anexo = AnexoDeAprovacao.new(params[:anexo])
#        anexo.erro # => nil, or "…is a text file; expected PNG, JPEG or PDF"
#        anexo.guardar!(aprovacao) # writes the file, fills anexo_* columns
class AnexoDeAprovacao
  MAX_SIZE = 20.megabytes
  ASSINATURAS = {
    "png" => [ "image/png", "\x89PNG\r\n\x1A\n".b ],
    "jpg" => [ "image/jpeg", "\xFF\xD8\xFF".b ],
    "pdf" => [ "application/pdf", "%PDF-".b ]
  }.freeze

  # Usage: AnexoDeAprovacao.extensao_do_tipo("application/pdf") # => "pdf"
  def self.extensao_do_tipo(tipo)
    ASSINATURAS.find { |_ext, (mime, _assinatura)| mime == tipo }&.first
  end

  def initialize(upload)
    @upload = upload
  end

  def presente?
    @upload.respond_to?(:tempfile)
  end

  def erro
    return unless presente?
    return "#{nome} is #{tamanho_legivel}; expected at most 20 MB" if @upload.tempfile.size > MAX_SIZE
    return "#{nome} is not a PNG, JPEG or PDF (checked by content)" unless extensao

    nil
  end

  def guardar!(aprovacao)
    destino = "#{aprovacao.uuid}.#{extensao}"
    dir = File.join(ArquivoVersion::STORAGE_BASE, aprovacao.arquivo.uuid, "aprovacoes")
    FileUtils.mkdir_p(dir)
    FileUtils.cp(@upload.tempfile.path, File.join(dir, destino))
    aprovacao.update_columns(anexo_arquivo: destino, anexo_nome: nome, anexo_tipo: ASSINATURAS.fetch(extensao).first)
  end

  private

  def extensao
    @extensao ||= begin
      inicio = File.binread(@upload.tempfile.path, 8).to_s
      ASSINATURAS.find { |_ext, (_tipo, assinatura)| inicio.start_with?(assinatura) }&.first
    end
  end

  def nome
    File.basename(@upload.original_filename.to_s)
  end

  def tamanho_legivel
    ActiveSupport::NumberHelper.number_to_human_size(@upload.tempfile.size)
  end
end
