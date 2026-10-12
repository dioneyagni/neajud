# The average color of an image file, in CIE Lab (Etapa 2.5b): the thin
# interface over ImageMagick for the cor lisa. A CMYK file goes to sRGB by
# the same ICC profiles as the previews (USWebCoatedSWOP → sRGB), the image
# is averaged to one pixel, and that sRGB (D65) becomes Lab here in Ruby.
# A fluorescent ink has no CMYK: its file is only an approximation.
#
# Usage: MedidaDeCor.new.medir("/…/original/cor.tif") # => { lab: [54.3, 64.7, 55.3], hex: "#EF4123" }
class MedidaDeCor
  class Falhou < StandardError; end

  ICC = Rails.root.join("config/icc")
  # sRGB → XYZ (D65), and the D65 white.
  MATRIZ = [ [ 0.4124, 0.3576, 0.1805 ], [ 0.2126, 0.7152, 0.0722 ], [ 0.0193, 0.1192, 0.9505 ] ].freeze
  BRANCO = [ 0.95047, 1.0, 1.08883 ].freeze

  def medir(caminho)
    hex = hex_medio(caminho.to_s)
    { lab: self.class.lab_do_hex(hex), hex: hex }
  end

  # Usage: MedidaDeCor.lab_do_hex("#0071BB") # => [46.2, 1.5, -46.3]
  def self.lab_do_hex(hex)
    rgb = hex.delete("#").scan(/../).map { |h| linear(h.to_i(16) / 255.0) }
    xyz = MATRIZ.each_with_index.map { |linha, i| linha.zip(rgb).sum { |m, v| m * v } / BRANCO[i] }
    fx, fy, fz = xyz.map { |t| t > 0.008856 ? t**(1.0 / 3) : 7.787 * t + 16.0 / 116 }
    [ 116 * fy - 16, 500 * (fx - fy), 200 * (fy - fz) ].map { |v| v.round(2) }
  end

  def self.linear(canal)
    canal <= 0.04045 ? canal / 12.92 : ((canal + 0.055) / 1.055)**2.4
  end

  private

  def hex_medio(caminho)
    saida = IO.popen([ "convert", "#{caminho}[0]", *perfis(caminho), "-alpha", "off", "-scale", "1x1!", "-depth", "8", "txt:-" ], err: File::NULL, &:read)
    saida[/#\h{6}/]&.upcase || raise(Falhou, "ImageMagick gave no color for #{caminho}; expected one sRGB pixel (txt:-), got #{saida.to_s[0, 80].inspect}")
  end

  def perfis(caminho)
    espaco = IO.popen([ "identify", "-format", "%[colorspace]\n", "#{caminho}[0]" ], err: File::NULL, &:read).to_s.lines.first.to_s.strip
    espaco == "CMYK" ? [ "-profile", ICC.join("USWebCoatedSWOP.icc").to_s, "-profile", ICC.join("sRGB.icc").to_s ] : []
  end
end
