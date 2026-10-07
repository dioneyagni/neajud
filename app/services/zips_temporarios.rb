# Where the Impressão page's zips are built (Etapa 1.2, 3/3 parte 3c): they
# can be gigabytes, so they go to disk, not memory. send_file streams them
# after the action returns, so they can't be deleted right away: each new
# zip first removes the ones older than an hour.
#
# Usage: destino = ZipsTemporarios.novo_caminho # => ".../tmp/zips/<uuid>.zip"
class ZipsTemporarios
  PASTA = Rails.root.join("tmp", "zips")
  VALIDADE = 1.hour

  def self.novo_caminho
    FileUtils.mkdir_p(PASTA)
    Dir.glob(PASTA.join("*.zip")).each { |velho| File.delete(velho) if File.mtime(velho) < VALIDADE.ago }
    PASTA.join("#{SecureRandom.uuid}.zip").to_s
  end
end
