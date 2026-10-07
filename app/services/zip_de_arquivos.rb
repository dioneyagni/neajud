# The project's thin wrapper around rubyzip (AGENTS.md "Dependencies"):
# files on disk into one .zip — in memory for small files (the Corte page's
# DXFs), or straight to a file for big ones (the Impressão page's artes, up
# to 1 GB each: stored, not compressed, and copied in chunks so nothing is
# held in memory; Etapa 1.2, 3/3 parte 3c).
#
# Usage: ZipDeArquivos.gerar("Lateral 29-30.dxf" => "/…/1.dxf") # => "PK\x03\x04…"
#        ZipDeArquivos.gravar({ "Lateral.tif" => "/…/original.tif" }, "/tmp/artes.zip")
class ZipDeArquivos
  def self.gerar(entradas)
    Zip::OutputStream.write_buffer { |zip| escrever(zip, entradas, Zip::Entry::DEFLATED) }.string
  end

  def self.gravar(entradas, destino)
    File.open(destino, "wb") do |arquivo|
      Zip::OutputStream.write_buffer(arquivo) { |zip| escrever(zip, entradas, Zip::Entry::STORED) }
    end
    destino
  end

  def self.escrever(zip, entradas, compressao)
    entradas.each do |nome, caminho|
      zip.put_next_entry(nome, "", Zip::ExtraField.new, compressao)
      File.open(caminho, "rb") { |origem| IO.copy_stream(origem, zip) }
    end
  end
  private_class_method :escrever
end
