# Copies a TIFF's Photoshop resource block (tag 34377) from one file to
# another (Etapa 2.6b2, decided 15/10/2026). tiffcrop rotates every sample —
# the DTF's white spot channels included — but drops this block, and the
# spot channels' names live there: a RIP reading "Spot_1" as the white would
# get an unnamed channel. Nothing else of the block depends on the
# orientation that a RIP reads.
#
# Plain byte work on classic TIFF (both byte orders): the block is appended
# with a new first directory that points at it; the old directory's next
# pointer is kept, so later directories stay. BigTIFF raises.
#
# Usage: BlocoPhotoshopDoTiff.copiar(original, girado) # => true (false: the original has none)
class BlocoPhotoshopDoTiff
  TAG = 34_377
  TIPO_UNDEFINED = 7

  class Invalido < StandardError; end

  def self.copiar(origem, destino)
    bloco = Tiff.new(File.binread(origem)).valor(TAG)
    return false unless bloco

    tiff = Tiff.new(File.binread(destino))
    File.binwrite(destino, tiff.com_tag(TAG, TIPO_UNDEFINED, bloco))
    true
  end

  # The first directory of a classic TIFF, read and rewritten.
  class Tiff
    def initialize(bytes)
      @bytes = bytes.b
      ordem = @bytes[0, 2]
      raise Invalido, "not a classic TIFF: header #{@bytes[0, 4].inspect}, expected II*\\0 or MM\\0*" unless [ "II", "MM" ].include?(ordem) && u16(2) == 42

      @f16, @f32 = ordem == "II" ? %w[v V] : %w[n N]
    end

    # The bytes of a tag in the first directory, or nil.
    def valor(tag)
      entrada = entradas.find { |e| e.unpack1(@f16) == tag }
      return nil unless entrada

      contagem = entrada[4, 4].unpack1(@f32)
      contagem <= 4 ? entrada[8, contagem] : @bytes[entrada[8, 4].unpack1(@f32), contagem]
    end

    # The file with that tag (replaced if present) in a new first directory.
    def com_tag(tag, tipo, valor)
      saida = @bytes.dup
      saida << "\0" if saida.size.odd?
      deslocamento = saida.size
      saida << valor
      saida << "\0" if saida.size.odd?
      novas = entradas.reject { |e| e.unpack1(@f16) == tag } << [ tag, tipo, valor.bytesize, deslocamento ].pack("#{@f16}#{@f16}#{@f32}#{@f32}")
      diretorio = saida.size
      saida << [ novas.size ].pack(@f16) << novas.sort_by { |e| e.unpack1(@f16) }.join << [ proximo ].pack(@f32)
      saida[4, 4] = [ diretorio ].pack(@f32)
      saida
    end

    private

    def primeiro
      @primeiro ||= u32(4)
    end

    def entradas
      @entradas ||= Array.new(u16(primeiro)) { |i| @bytes[primeiro + 2 + i * 12, 12] }
    end

    def proximo
      u32(primeiro + 2 + entradas.size * 12)
    end

    def u16(posicao)
      @bytes[posicao, 2].unpack1(@f16 || (@bytes[0, 2] == "II" ? "v" : "n"))
    end

    def u32(posicao)
      @bytes[posicao, 4].unpack1(@f32)
    end
  end
end
