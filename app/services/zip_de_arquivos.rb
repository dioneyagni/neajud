# The project's thin wrapper around rubyzip (AGENTS.md "Dependencies"):
# files on disk into one .zip, in memory.
#
# Usage: ZipDeArquivos.gerar("Lateral 29-30.dxf" => "/…/1.dxf") # => "PK\x03\x04…"
class ZipDeArquivos
  def self.gerar(entradas)
    Zip::OutputStream.write_buffer do |zip|
      entradas.each do |nome, caminho|
        zip.put_next_entry(nome)
        zip.write(File.binread(caminho))
      end
    end.string
  end
end
