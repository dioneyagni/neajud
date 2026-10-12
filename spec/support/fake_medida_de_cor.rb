# Stands in for MedidaDeCor (ImageMagick) in specs of a cor lisa: answers
# the hex it was given — for any file, or per file name — as MedidaDeCor
# would, with its Lab. Records the paths it measured.
#
# Usage: MedirCorJob.medidor = FakeMedidaDeCor.new("#EF4123", "azul.tif" => "#0071BB")
class FakeMedidaDeCor
  attr_reader :medidos

  def initialize(padrao = "#808080", por_nome = {})
    @padrao = padrao
    @por_nome = por_nome
    @medidos = []
  end

  def medir(caminho)
    @medidos << caminho.to_s
    hex = @por_nome.find { |nome, _| caminho.to_s.include?(nome) }&.last || @padrao
    { lab: MedidaDeCor.lab_do_hex(hex), hex: hex }
  end

  # The next files measure as this color (a new version, a tone adjustment).
  def passar_a_medir(hex)
    @padrao = hex
    @por_nome = {}
  end
end
